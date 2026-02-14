//+------------------------------------------------------------------+
//|                                                  CandleTypeDetector.mqh |
//|                                       شناسایی نوع کندل بر اساس توضیحات |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"
#property strict

enum ENUM_CANDLE_TYPE
{
   CANDLE_NONE,          // نامشخص
   CANDLE_PINBAR,       // پین بار
   CANDLE_ENGULFING,    // انگالف (بازگشتی)
   CANDLE_DOJI,         // دوجی
   CANDLE_BULLISH,      // کندل صعودی قوی
   CANDLE_BEARISH,      // کندل نزولی قوی
   CANDLE_SPIKE         // کندل اسپایک
};

class CandleTypeDetector
{
private:
   double bodySizeMin;  // حداقل نسبت بدنه به شدو برای کندل قوی
   double pinbarRatio;  // نسبت شدو به بدنه برای پین بار
public:
   CandleTypeDetector()
   {
      bodySizeMin = 0.5;     // بدنه حداقل 50% کل کندل
      pinbarRatio = 2.0;     // شدو حداقل 2 برابر بدنه
   }
   
   // محاسبه اندازه بدنه
   double BodySize(const MqlRates &candle)
   {
      return MathAbs(candle.close - candle.open);
   }
   
   // محاسبه شدو بالا
   double UpperShadow(const MqlRates &candle)
   {
      if(candle.close > candle.open)
         return candle.high - candle.close;
      else
         return candle.high - candle.open;
   }
   
   // محاسبه شدو پایین
   double LowerShadow(const MqlRates &candle)
   {
      if(candle.close > candle.open)
         return candle.open - candle.low;
      else
         return candle.close - candle.low;
   }
   
   // بدنه نسبت به کل محدوده
   double BodyToRangeRatio(const MqlRates &candle)
   {
      double range = candle.high - candle.low;
      if(range == 0) return 1;
      return BodySize(candle) / range;
   }
   
   // تشخیص پین بار
   bool IsPinBar(const MqlRates &candle, bool bullishTrend = true)
   {
      double body = BodySize(candle);
      double upper = UpperShadow(candle);
      double lower = LowerShadow(candle);
      double range = candle.high - candle.low;
      
      if(body == 0) return false;
      
      // پین بار صعودی (دم پایین بلند)
      if(bullishTrend)
      {
         if(lower > body * pinbarRatio && upper < body * 0.3)
            return true;
      }
      else // پین بار نزولی (دم بالا بلند)
      {
         if(upper > body * pinbarRatio && lower < body * 0.3)
            return true;
      }
      
      return false;
   }
   
   // تشخیص انگالف
   bool IsEngulfing(const MqlRates &current, const MqlRates &prev)
   {
      if(current.close > current.open) // کندل سبز فعلی
      {
         if(prev.close < prev.open) // کندل قرمز قبلی
         {
            if(current.open < prev.close && current.close > prev.open)
               return true;
         }
      }
      else if(current.close < current.open) // کندل قرمز فعلی
      {
         if(prev.close > prev.open) // کندل سبز قبلی
         {
            if(current.open > prev.close && current.close < prev.open)
               return true;
         }
      }
      return false;
   }
   
   // کندل قوی (بدنه بزرگ، شدو کم)
   bool IsStrongBody(const MqlRates &candle)
   {
      double bodyRatio = BodyToRangeRatio(candle);
      return (bodyRatio >= bodySizeMin);
   }
   
   // تشخیص دوجی
   bool IsDoji(const MqlRates &candle)
   {
      double body = BodySize(candle);
      double range = candle.high - candle.low;
      if(range == 0) return false;
      return (body / range) < 0.1;
   }
   
   // اسپایک: چند کندل قوی هم‌جهت بدون همپوشانی زیاد
   bool IsSpike(const MqlRates &candlesArray[], int index, int lookback = 3)
   {
      if(index < lookback - 1) return false;
      
      bool directionUp = candlesArray[index].close > candlesArray[index].open;
      
      for(int i = 0; i < lookback; i++)
      {
         int idx = index - i;
         if(idx < 0) return false;
         
         // همه کندلها باید همجهت باشند
         if((candlesArray[idx].close > candlesArray[idx].open) != directionUp)
            return false;
         
         // بدنه باید قوی باشد
         if(!IsStrongBody(candlesArray[idx]))
            return false;
            
         // همپوشانی کم
         if(i > 0)
         {
            if(directionUp)
            {
               if(candlesArray[idx].high < candlesArray[idx+1].high)
                  return false;
            }
            else
            {
               if(candlesArray[idx].low > candlesArray[idx+1].low)
                  return false;
            }
         }
      }
      return true;
   }
   
   // تشخیص نوع کلی کندل
   ENUM_CANDLE_TYPE GetCandleType(const MqlRates &current, const MqlRates &prev)
   {
      if(IsDoji(current))
         return CANDLE_DOJI;
      
      if(IsEngulfing(current, prev))
         return CANDLE_ENGULFING;
      
      if(IsPinBar(current, true) || IsPinBar(current, false))
         return CANDLE_PINBAR;
      
      if(IsStrongBody(current))
      {
         if(current.close > current.open)
            return CANDLE_BULLISH;
         else
            return CANDLE_BEARISH;
      }
      
      return CANDLE_NONE;
   }
};