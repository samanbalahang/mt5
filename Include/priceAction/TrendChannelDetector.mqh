//+------------------------------------------------------------------+
//|                                                TrendChannelDetector.mqh |
//|                                        تشخیص خط روند، کانال، رنج، تراکم |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"

#include "CandleTypeDetector.mqh"

enum ENUM_MARKET_CYCLE
{
   CYCLE_SPIKE,        // اسپایک - حرکت قوی یکطرفه
   CYCLE_CHANNEL,      // کانال - ادامه روند با شیب کمتر
   CYCLE_RANGE,        // تریدینگ رنج - پولبک بالا و پایین
   CYCLE_UNDEFINED
};

enum ENUM_TREND_DIRECTION
{
   TREND_UP,          // صعودی
   TREND_DOWN,        // نزولی
   TREND_SIDEWAYS,    // رنج
   TREND_UNDEFINED
};

struct SwingPoint
{
   datetime time;     // زمان
   double   price;    // قیمت
   bool     isHigh;   // true = سقف، false = کف
   int      strength; // قدرت (تعداد برخوردها)
};

struct TrendLine
{
   double   p1_time, p1_price;
   double   p2_time, p2_price;
   bool     isDynamic;  // true = داینامیک (مورب)، false = استاتیک (افقی)
   bool     isValid;    // اعتبار
   double   angle;      // شیب
   int      touches;    // تعداد برخورد
};

struct Channel
{
   TrendLine upper;    // خط بالایی
   TrendLine lower;    // خط پایینی
   bool      isValid;
   double    height;    // ارتفاع کانال
};

class TrendChannelDetector
{
private:
   CandleTypeDetector candleDetector;
   int maxSwingLookback;
   double touchTolerance;  // تلورانس برخورد به خط
  
public:
   TrendChannelDetector()
   {
      maxSwingLookback = 50;
      touchTolerance = 0.001; // 0.1% قابل تنظیم
   }
   
   // تشخیص سقف/کف محلی
   bool IsSwingHigh(const MqlRates &candles[], int index, int strength = 2)
   {
      if(index < strength || index >= ArraySize(candles) - strength)
         return false;
      
      double currentHigh = candles[index].high;
      
      for(int i = 1; i <= strength; i++)
      {
         if(candles[index - i].high >= currentHigh)
            return false;
         if(candles[index + i].high >= currentHigh)
            return false;
      }
      return true;
   }
   
   bool IsSwingLow(const MqlRates &candles[], int index, int strength = 2)
   {
      if(index < strength || index >= ArraySize(candles) - strength)
         return false;
      
      double currentLow = candles[index].low;
      
      for(int i = 1; i <= strength; i++)
      {
         if(candles[index - i].low <= currentLow)
            return false;
         if(candles[index + i].low <= currentLow)
            return false;
      }
      return true;
   }
   
   // تشخیص روند کلی
   ENUM_TREND_DIRECTION DetectTrend(const MqlRates &candles[], int startIdx, int count = 20)
   {
      if(ArraySize(candles) < startIdx + count)
         return TREND_UNDEFINED;
      
      int higherHighs = 0, higherLows = 0;
      int lowerHighs = 0, lowerLows = 0;
      
      for(int i = startIdx; i < startIdx + count - 1; i++)
      {
         if(IsSwingHigh(candles, i, 1))
         {
            if(candles[i].high > candles[i+1].high)
               higherHighs++;
            else
               lowerHighs++;
         }
         
         if(IsSwingLow(candles, i, 1))
         {
            if(candles[i].low > candles[i+1].low)
               higherLows++;
            else
               lowerLows++;
         }
      }
      
      if(higherHighs + higherLows > lowerHighs + lowerLows + 3)
         return TREND_UP;
      else if(lowerHighs + lowerLows > higherHighs + higherLows + 3)
         return TREND_DOWN;
      else
         return TREND_SIDEWAYS;
   }
   
   // تشخیص تریدینگ رنج (پولبک بالا و پایین پشت سر هم)
   bool IsTradingRange(const MqlRates &candles[], int startIdx, int period = 10)
   {
      if(ArraySize(candles) < startIdx + period)
         return false;
      
      int pullbackCount = 0;
      
      for(int i = startIdx; i < startIdx + period - 1; i++)
      {
         // پولبک پایین در روند صعودی
         if(candles[i].low < candles[i+1].low)
            pullbackCount++;
         // پولبک بالا در روند نزولی
         if(candles[i].high > candles[i+1].high)
            pullbackCount++;
      }
      
      // اگر بیش از 60% کندل‌ها پولبک داشته باشند
      return (pullbackCount >= period * 0.6);
   }
   
   // تشخیص اسپایک
   bool IsSpikePhase(const MqlRates &candles[], int index, int minSpikeCandles = 4)
   {
      if(index < minSpikeCandles)
         return false;
      
      // بررسی جهت اسپایک
      bool isUpward = true;
      int upCount = 0, downCount = 0;
      
      for(int i = 0; i < minSpikeCandles; i++)
      {
         if(candles[index - i].close > candles[index - i].open)
            upCount++;
         else
            downCount++;
      }
      
      if(upCount >= minSpikeCandles - 1)
         isUpward = true;
      else if(downCount >= minSpikeCandles - 1)
         isUpward = false;
      else
         return false;
      
      // بررسی قدرت کندلها
      for(int i = 0; i < minSpikeCandles; i++)
      {
         if(!candleDetector.IsStrongBody(candles[index - i]))
            return false;
         
         // لوی‌های بالاتر برای اسپایک صعودی
         if(i > 0)
         {
            if(isUpward)
            {
               if(candles[index - i].high <= candles[index - i + 1].high)
                  return false;
            }
            else
            {
               if(candles[index - i].low >= candles[index - i + 1].low)
                  return false;
            }
         }
      }
      
      return true;
   }
   
   // تشخیص کانال
   bool DetectChannel(const MqlRates &candles[], int startIdx, int endIdx, Channel &outChannel)
   {
      if(endIdx - startIdx < 10)
         return false;
      
      // پیدا کردن سقف‌ها و کف‌های اصلی
      double highs[], lows[];
      ArrayResize(highs, 0);
      ArrayResize(lows, 0);
      
      for(int i = startIdx; i <= endIdx; i++)
      {
         if(IsSwingHigh(candles, i, 2))
         {
            ArrayResize(highs, ArraySize(highs) + 1);
            highs[ArraySize(highs) - 1] = candles[i].high;
         }
         if(IsSwingLow(candles, i, 2))
         {
            ArrayResize(lows, ArraySize(lows) + 1);
            lows[ArraySize(lows) - 1] = candles[i].low;
         }
      }
      
      if(ArraySize(highs) < 2 || ArraySize(lows) < 2)
         return false;
      
      // خط بالایی کانال: میانگین سقف‌ها
      double upperAvg = 0;
      for(int i = 0; i < ArraySize(highs); i++)
         upperAvg += highs[i];
      upperAvg /= ArraySize(highs);
      
      // خط پایینی کانال: میانگین کف‌ها
      double lowerAvg = 0;
      for(int i = 0; i < ArraySize(lows); i++)
         lowerAvg += lows[i];
      lowerAvg /= ArraySize(lows);
      
      outChannel.upper.p1_price = upperAvg;
      outChannel.upper.p2_price = upperAvg;
      outChannel.lower.p1_price = lowerAvg;
      outChannel.lower.p2_price = lowerAvg;
      outChannel.height = upperAvg - lowerAvg;
      outChannel.isValid = (outChannel.height > 0);
      
      return outChannel.isValid;
   }
   
   // تشخیص سایکل بازار
   ENUM_MARKET_CYCLE DetectMarketCycle(const MqlRates &candles[], int index, int lookback = 20)
   {
      if(index < lookback)
         return CYCLE_UNDEFINED;
      
      // 1. بررسی اسپایک
      if(IsSpikePhase(candles, index, 4))
         return CYCLE_SPIKE;
      
      // 2. بررسی تریدینگ رنج
      if(IsTradingRange(candles, index - lookback, lookback))
         return CYCLE_RANGE;
      
      // 3. بررسی کانال (حرکت منظم بین دو خط موازی)
      Channel dummy;
      if(DetectChannel(candles, index - lookback, index, dummy))
      {
         // اگر ارتفاع کانال ثابت و شیب ملایم باشد
         return CYCLE_CHANNEL;
      }
      
      return CYCLE_UNDEFINED;
   }
   
   // محاسبه قدرت روند
   double CalculateTrendStrength(const MqlRates &candles[], int index)
   {
      if(index < 10) return 0;
      
      double strength = 0;
      
      // 1. فاصله سقف از کف قبلی
      double lastHigh = candles[index].high;
      double prevLow = candles[index - 5].low;
      double distance = (lastHigh - prevLow) / prevLow * 100;
      
      // 2. بررسی سوراخ شدن سقف قبلی
      bool touchedPreviousHigh = false;
      for(int i = 1; i <= 10; i++)
      {
         if(index - i >= 0)
         {
            if(candles[index].high >= candles[index - i].high)
               touchedPreviousHigh = true;
         }
      }
      
      // 3. همپوشانی نواحی
      double overlap = 0;
      for(int i = 1; i <= 5; i++)
      {
         if(index - i >= 0)
         {
            if(candles[index].low < candles[index - i].high)
               overlap += (candles[index - i].high - candles[index].low);
         }
      }
      
      // امتیازدهی
      if(distance > 0.5) strength += 2;
      if(!touchedPreviousHigh) strength += 3;
      if(overlap < candles[index].high - candles[index].low) strength += 2;
      
      // روند بسیار قوی: کف فعلی سقف قبلی را سوراخ نکند
      if(!touchedPreviousHigh && distance > 1.0)
         strength += 5;
      
      return strength;
   }
   
   // تشخیص شکست خط روند
   bool IsTrendLineBreak(const MqlRates &candles[], int index, TrendLine &line, int lookback = 3)
   {
      if(!line.isValid) return false;
      
      // بررسی بسته شدن کندل بالای/پایین خط
      double lineValue = line.p1_price + (line.p2_price - line.p1_price) * 
                         (index - line.p1_time) / (line.p2_time - line.p1_time);
      
      for(int i = 0; i < lookback; i++)
      {
         if(index - i < 0) break;
         
         if(line.isDynamic)
         {
            if(candles[index - i].close > lineValue + touchTolerance)
               return true;
            if(candles[index - i].close < lineValue - touchTolerance)
               return true;
         }
         else
         {
            if(candles[index - i].close > line.p1_price + touchTolerance)
               return true;
            if(candles[index - i].close < line.p1_price - touchTolerance)
               return true;
         }
      }
      
      return false;
   }
};