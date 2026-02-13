//+------------------------------------------------------------------+
//|                                             SupportResistanceManager.mqh |
//|                                        مدیریت سطوح حمایت و مقاومت استاتیک/داینامیک |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"

#include "TrendChannelDetector.mqh"

enum ENUM_LEVEL_TYPE
{
   LEVEL_STATIC_HORIZONTAL,    // افقی
   LEVEL_DYNAMIC_TRENDLINE,    // مورب (خط روند)
   LEVEL_DYNAMIC_MA,           // میانگین متحرک
   LEVEL_WEEKLY,              // سطح هفتگی
   LEVEL_MONTHLY,            // سطح ماهانه
   LEVEL_PREV_DAY_HL,        // کف و سقف روز قبل
   LEVEL_FIBONACCI           // فیبوناچی
};

enum ENUM_LEVEL_STRENGTH
{
   STRENGTH_WEAK,        // ضعیف (1 برخورد)
   STRENGTH_MEDIUM,      // متوسط (2 برخورد)
   STRENGTH_STRONG,      // قوی (3+ برخورد)
   STRENGTH_MAJOR        // بسیار قوی (تایم فریم بالاتر)
};

struct SupportResistanceLevel
{
   double            price;        // قیمت سطح
   datetime          time;         // زمان ایجاد
   ENUM_LEVEL_TYPE   type;         // نوع سطح
   ENUM_LEVEL_STRENGTH strength;   // قدرت
   int               touchCount;   // تعداد برخورد
   bool              isBroken;     // شکسته شده؟
   datetime          brokenTime;   // زمان شکست
   string            levelName;    // نام سطح
   bool              isValid;      // اعتبار
};

struct FibonacciLevel
{
   double level;      // 0, 0.25, 0.5, 0.75, 1
   double price;      // قیمت محاسبه شده
   bool   isActive;
};

class SupportResistanceManager
{
private:
   TrendChannelDetector trendDetector;
   SupportResistanceLevel levels[];  // آرایه سطوح
   int maxLevelsToTrack;
   double touchTolerance;
   
public:
   SupportResistanceManager()
   {
      maxLevelsToTrack = 50;
      touchTolerance = 0.0005;  // 0.05% قابل تنظیم
      ArrayResize(levels, 0);
   }
   
   // اضافه کردن سطح جدید
   void AddLevel(double price, datetime time, ENUM_LEVEL_TYPE type, string name = "")
   {
      // بررسی تکراری نبودن
      for(int i = 0; i < ArraySize(levels); i++)
      {
         if(MathAbs(levels[i].price - price) < price * touchTolerance)
         {
            levels[i].touchCount++;
            UpdateLevelStrength(i);
            return;
         }
      }
      
      // اضافه سطح جدید
      int idx = ArraySize(levels);
      ArrayResize(levels, idx + 1);
      
      levels[idx].price = price;
      levels[idx].time = time;
      levels[idx].type = type;
      levels[idx].touchCount = 1;
      levels[idx].isBroken = false;
      levels[idx].isValid = true;
      levels[idx].levelName = name;
      
      UpdateLevelStrength(idx);
   }
   
   // بروزرسانی قدرت سطح بر اساس تعداد برخورد
   void UpdateLevelStrength(int index)
   {
      if(index >= ArraySize(levels)) return;
      
      if(levels[index].touchCount >= 4)
         levels[index].strength = STRENGTH_MAJOR;
      else if(levels[index].touchCount >= 3)
         levels[index].strength = STRENGTH_STRONG;
      else if(levels[index].touchCount >= 2)
         levels[index].strength = STRENGTH_MEDIUM;
      else
         levels[index].strength = STRENGTH_WEAK;
   }
   
   // تشخیص برخورد به سطح
   bool IsTouchingLevel(double price, const SupportResistanceLevel &level)
   {
      return MathAbs(price - level.price) < price * touchTolerance;
   }
   
   // تشخیص شکست سطح
   bool IsLevelBroken(const MqlRates &candles[], int index, int levelIdx)
   {
      if(levelIdx >= ArraySize(levels)) return false;
      if(levels[levelIdx].isBroken) return true;
      
      double close = candles[index].close;
      double levelPrice = levels[levelIdx].price;
      
      // کندل بالای مقاومت بسته شده
      if(close > levelPrice + levelPrice * touchTolerance * 2)
      {
         levels[levelIdx].isBroken = true;
         levels[levelIdx].brokenTime = candles[index].time;
         
         // تبدیل مقاومت به حمایت
         AddLevel(levelPrice, candles[index].time, LEVEL_STATIC_HORIZONTAL, 
                  "Broken Resistance -> Support");
         return true;
      }
      
      // کندل پایین حمایت بسته شده
      if(close < levelPrice - levelPrice * touchTolerance * 2)
      {
         levels[levelIdx].isBroken = true;
         levels[levelIdx].brokenTime = candles[index].time;
         
         // تبدیل حمایت به مقاومت
         AddLevel(levelPrice, candles[index].time, LEVEL_STATIC_HORIZONTAL,
                  "Broken Support -> Resistance");
         return true;
      }
      
      return false;
   }
   
   // رسم سطوح افقی از کندل روز قبل
   void AddPrevDayLevels(const MqlRates &dailyCandle)
   {
      // سقف روز قبل (با احتساب شدو)
      AddLevel(dailyCandle.high, dailyCandle.time, LEVEL_PREV_DAY_HL, "Prev Day High");
      
      // کف روز قبل (با احتساب شدو)
      AddLevel(dailyCandle.low, dailyCandle.time, LEVEL_PREV_DAY_HL, "Prev Day Low");
      
      // اپن روز قبل (اختیاری)
      AddLevel(dailyCandle.open, dailyCandle.time, LEVEL_PREV_DAY_HL, "Prev Day Open");
   }
   
   // رسم سطوح هفتگی و ماهانه
   void AddWeeklyMonthlyLevels(double weeklyHigh, double weeklyLow, 
                              double monthlyHigh, double monthlyLow, datetime time)
   {
      AddLevel(weeklyHigh, time, LEVEL_WEEKLY, "Weekly High");
      AddLevel(weeklyLow, time, LEVEL_WEEKLY, "Weekly Low");
      AddLevel(monthlyHigh, time, LEVEL_MONTHLY, "Monthly High");
      AddLevel(monthlyLow, time, LEVEL_MONTHLY, "Monthly Low");
   }
   
   // محاسبه سطوح فیبوناچی
   void CalculateFibonacciLevels(double startPrice, double endPrice, datetime time)
   {
      double fibLevels[] = {0.0, 0.25, 0.5, 0.75, 1.0};
      string fibNames[] = {"Fib 0%", "Fib 25%", "Fib 50%", "Fib 75%", "Fib 100%"};
      
      double range = MathAbs(endPrice - startPrice);
      bool isUptrend = (endPrice > startPrice);
      
      for(int i = 0; i < ArraySize(fibLevels); i++)
      {
         double levelPrice;
         
         if(isUptrend)
            levelPrice = startPrice + range * fibLevels[i];
         else
            levelPrice = startPrice - range * fibLevels[i];
         
         AddLevel(levelPrice, time, LEVEL_FIBONACCI, fibNames[i]);
      }
   }
   
   // پیدا کردن نزدیکترین سطح حمایت
   double FindNearestSupport(double currentPrice)
   {
      double nearest = 0;
      double minDistance = DBL_MAX;
      
      for(int i = 0; i < ArraySize(levels); i++)
      {
         if(!levels[i].isValid || levels[i].isBroken) continue;
         
         if(levels[i].price < currentPrice)
         {
            double distance = currentPrice - levels[i].price;
            if(distance < minDistance)
            {
               minDistance = distance;
               nearest = levels[i].price;
            }
         }
      }
      
      return (nearest > 0) ? nearest : currentPrice * 0.95;
   }
   
   // پیدا کردن نزدیکترین سطح مقاومت
   double FindNearestResistance(double currentPrice)
   {
      double nearest = 0;
      double minDistance = DBL_MAX;
      
      for(int i = 0; i < ArraySize(levels); i++)
      {
         if(!levels[i].isValid || levels[i].isBroken) continue;
         
         if(levels[i].price > currentPrice)
         {
            double distance = levels[i].price - currentPrice;
            if(distance < minDistance)
            {
               minDistance = distance;
               nearest = levels[i].price;
            }
         }
      }
      
      return (nearest > 0) ? nearest : currentPrice * 1.05;
   }
   
   // تشخیص ناحیه PRZ (Potential Reversal Zone)
   bool IsPRZ(double price, int lookback = 5)
   {
      int levelCount = 0;
      
      for(int i = 0; i < ArraySize(levels); i++)
      {
         if(!levels[i].isValid || levels[i].isBroken) continue;
         
         if(MathAbs(price - levels[i].price) < price * 0.001) // 0.1%
            levelCount++;
      }
      
      // اگر حداقل ۲ سطح در یک ناحیه باشند
      return (levelCount >= 2);
   }
   
   // پاکسازی سطوح قدیمی
   void CleanOldLevels(datetime currentTime, int daysToKeep = 30)
   {
      for(int i = ArraySize(levels) - 1; i >= 0; i--)
      {
         if(currentTime - levels[i].time > daysToKeep * 86400)
         {
            // حذف سطح
            for(int j = i; j < ArraySize(levels) - 1; j++)
               levels[j] = levels[j + 1];
            ArrayResize(levels, ArraySize(levels) - 1);
         }
      }
   }
   
   // دریافت سطوح فعال
   int GetActiveLevels(SupportResistanceLevel &outLevels[])
   {
      int count = 0;
      ArrayResize(outLevels, ArraySize(levels));
      
      for(int i = 0; i < ArraySize(levels); i++)
      {
         if(levels[i].isValid && !levels[i].isBroken)
         {
            outLevels[count] = levels[i];
            count++;
         }
      }
      
      ArrayResize(outLevels, count);
      return count;
   }
   
   // رسم خطوط مورب (داینامیک)
   void AddDynamicLevel(TrendLine &line, datetime time)
   {
      if(!line.isValid) return;
      
      // خطوط مورب به عنوان سطح داینامیک اضافه می‌شوند
      AddLevel(line.p1_price, time, LEVEL_DYNAMIC_TRENDLINE, "Dynamic Trendline");
      
      // نقطه دوم هم اضافه شود؟
      if(line.p2_price != line.p1_price)
      {
         AddLevel(line.p2_price, time, LEVEL_DYNAMIC_TRENDLINE, "Dynamic Trendline");
      }
   }
   
   // تشخیص همپوشانی سطوح
   bool HasOverlap(double price1, double price2, double tolerance = 0.002)
   {
      double lower = MathMin(price1, price2);
      double upper = MathMax(price1, price2);
      
      for(int i = 0; i < ArraySize(levels); i++)
      {
         if(!levels[i].isValid || levels[i].isBroken) continue;
         
         if(levels[i].price >= lower * (1 - tolerance) && 
            levels[i].price <= upper * (1 + tolerance))
         {
            return true;
         }
      }
      
      return false;
   }
   
   // توصیه برای استاپ لاس
   double SuggestStopLoss(double entryPrice, bool isLong)
   {
      if(isLong)
      {
         double nearestSupport = FindNearestSupport(entryPrice);
         // استاپ زیر شدو: کمی پایینتر از حمایت
         return nearestSupport * 0.999;
      }
      else
      {
         double nearestResistance = FindNearestResistance(entryPrice);
         // استاپ بالای شدو: کمی بالاتر از مقاومت
         return nearestResistance * 1.001;
      }
   }
   
   // توصیه برای تیک پروفیت
   double SuggestTakeProfit(double entryPrice, bool isLong, double riskReward = 2.0)
   {
      double stopDistance;
      
      if(isLong)
      {
         double stop = SuggestStopLoss(entryPrice, true);
         stopDistance = MathAbs(entryPrice - stop);
         return entryPrice + (stopDistance * riskReward);
      }
      else
      {
         double stop = SuggestStopLoss(entryPrice, false);
         stopDistance = MathAbs(entryPrice - stop);
         return entryPrice - (stopDistance * riskReward);
      }
   }
   
   // دریافت قدرت سطح
   string GetLevelStrengthDescription(int index)
   {
      if(index >= ArraySize(levels)) return "";
      
      switch(levels[index].strength)
      {
         case STRENGTH_WEAK:    return "ضعیف (1 برخورد)";
         case STRENGTH_MEDIUM:  return "متوسط (2 برخورد)";
         case STRENGTH_STRONG:  return "قوی (3 برخورد)";
         case STRENGTH_MAJOR:   return "بسیار قوی (4+ برخورد)";
         default:               return "نامشخص";
      }
   }
};