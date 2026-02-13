//+------------------------------------------------------------------+
//|                                               MovingAverageManager.mqh |
//|                                        مدیریت میانگین‌های متحرک EMA20/50 |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"

enum ENUM_MA_TOUCH_TYPE
{
   MA_TOUCH_NONE,
   MA_TOUCH_BOUNCE,        // برخورد و برگشت
   MA_TOUCH_BREAK,         // شکست
   MA_TOUCH_FAKE_BREAK,    // فیک بریک
   MA_TOUCH_SUPPORT,       // حمایت
   MA_TOUCH_RESISTANCE     // مقاومت
};

struct MATouchInfo
{
   datetime          time;
   double            price;
   double            maValue;
   ENUM_MA_TOUCH_TYPE type;
   double            distance;      // فاصله از MA
   int               barIndex;
   bool              isBullish;
};

class MovingAverageManager
{
private:
   int               handleEMA20;
   int               handleEMA50;
   double            ema20Buffer[];
   double            ema50Buffer[];
   datetime          lastTouchTimeEMA20;
   double            lastTouchPriceEMA20;
   int               touchCountEMA20;
   MATouchInfo       touchesEMA20[];
   MATouchInfo       touchesEMA50[];
   
public:
   MovingAverageManager()
   {
      handleEMA20 = INVALID_HANDLE;
      handleEMA50 = INVALID_HANDLE;
      lastTouchTimeEMA20 = 0;
      lastTouchPriceEMA20 = 0;
      touchCountEMA20 = 0;
      ArrayResize(touchesEMA20, 0);
      ArrayResize(touchesEMA50, 0);
   }
   
   ~MovingAverageManager()
   {
      if(handleEMA20 != INVALID_HANDLE) IndicatorRelease(handleEMA20);
      if(handleEMA50 != INVALID_HANDLE) IndicatorRelease(handleEMA50);
   }
   
   // مقداردهی اولیه EMA
   bool InitializeEMA()
   {
      handleEMA20 = iMA(_Symbol, InpMainTimeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
      handleEMA50 = iMA(_Symbol, InpHigherTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      
      if(handleEMA20 == INVALID_HANDLE || handleEMA50 == INVALID_HANDLE)
      {
         Print("خطا در ایجاد اندیکاتور EMA");
         return false;
      }
      
      ArraySetAsSeries(ema20Buffer, true);
      ArraySetAsSeries(ema50Buffer, true);
      
      Print("EMA 20 و EMA 50 با موفقیت راه‌اندازی شدند");
      return true;
   }
   
   // به‌روزرسانی مقادیر EMA
   bool RefreshEMA()
   {
      if(handleEMA20 == INVALID_HANDLE) return false;
      
      if(CopyBuffer(handleEMA20, 0, 0, 100, ema20Buffer) < 20) return false;
      if(CopyBuffer(handleEMA50, 0, 0, 50, ema50Buffer) < 20) return false;
      
      return true;
   }
   
   // دریافت مقدار EMA20 در کندل مشخص
   double GetEMA20(int shift = 0)
   {
      if(ArraySize(ema20Buffer) > shift)
         return ema20Buffer[shift];
      return 0;
   }
   
   // دریافت مقدار EMA50 در کندل مشخص
   double GetEMA50(int shift = 0)
   {
      if(ArraySize(ema50Buffer) > shift)
         return ema50Buffer[shift];
      return 0;
   }
   
   // تشخیص برخورد به EMA
   ENUM_MA_TOUCH_TYPE CheckMATouch(const MqlRates &candle, double maValue, double tolerance = 0.001)
   {
      if(maValue == 0) return MA_TOUCH_NONE;
      
      double high = candle.high;
      double low = candle.low;
      double close = candle.close;
      double open = candle.open;
      
      // آیا قیمت EMA را لمس کرده؟
      bool touched = (low <= maValue * (1 + tolerance) && high >= maValue * (1 - tolerance));
      
      if(!touched) return MA_TOUCH_NONE;
      
      // تشخیص نوع برخورد
      bool isBullish = (close > open);
      
      // 1. فیک بریک: کندل بالای EMA بسته شده ولی زیر آن باز شده
      if(open < maValue && close > maValue)
      {
         RecordTouch(candle.time, maValue, MA_TOUCH_FAKE_BREAK, true);
         return MA_TOUCH_FAKE_BREAK;
      }
      
      // 2. شکست: کندل بالای EMA باز و بسته شده
      if(open > maValue && close > maValue)
      {
         RecordTouch(candle.time, maValue, MA_TOUCH_BREAK, true);
         return MA_TOUCH_BREAK;
      }
      
      // 3. برگشت: کندل بالای EMA باز شده ولی زیر آن بسته
      if(open > maValue && close < maValue)
      {
         RecordTouch(candle.time, maValue, MA_TOUCH_BOUNCE, false);
         return MA_TOUCH_BOUNCE;
      }
      
      // 4. حمایت/مقاومت
      if(close > maValue)
      {
         RecordTouch(candle.time, maValue, MA_TOUCH_SUPPORT, true);
         return MA_TOUCH_SUPPORT;
      }
      else
      {
         RecordTouch(candle.time, maValue, MA_TOUCH_RESISTANCE, false);
         return MA_TOUCH_RESISTANCE;
      }
   }
   
   // ثبت برخورد به EMA
   void RecordTouch(datetime time, double maValue, ENUM_MA_TOUCH_TYPE type, bool isBullish)
   {
      int idx = ArraySize(touchesEMA20);
      ArrayResize(touchesEMA20, idx + 1);
      
      touchesEMA20[idx].time = time;
      touchesEMA20[idx].maValue = maValue;
      touchesEMA20[idx].type = type;
      touchesEMA20[idx].isBullish = isBullish;
      touchesEMA20[idx].distance = 0;
      
      touchCountEMA20++;
      lastTouchTimeEMA20 = time;
      lastTouchPriceEMA20 = maValue;
   }
   
   // بررسی قانون 2 ساعت (نکته 107 و پولبک نکته 8)
   bool CheckTwoHourRule(datetime currentTime, double currentPrice)
   {
      if(lastTouchTimeEMA20 == 0) return false;
      
      // محاسبه اختلاف زمان بر حسب ساعت
      int hoursDiff = (int)((currentTime - lastTouchTimeEMA20) / 3600);
      
      if(hoursDiff >= 2)
      {
         double distance = MathAbs(currentPrice - GetEMA20()) / GetEMA20() * 100;
         
         // اگر بیش از 2 ساعت از EMA فاصله داریم و فاصله > 1%
         if(distance > 1.0)
         {
            Print("قانون 2 ساعت: ", hoursDiff, " ساعت از EMA20 فاصله - بازگشت قریب‌الوقوع");
            return true;
         }
      }
      
      return false;
   }
   
   // بررسی قدرت روند با EMA (نکته 30)
   double CalculateTrendStrengthWithEMA(const MqlRates &candles[], int index)
   {
      double strength = 0;
      
      if(index < 10) return strength;
      
      double ema20 = GetEMA20(0);
      double price = candles[index].close;
      
      // 1. فاصله از EMA20 (بیشتر = قویتر)
      double distance = MathAbs(price - ema20) / ema20 * 100;
      if(distance > 2.0) strength += 3;
      else if(distance > 1.0) strength += 2;
      else if(distance > 0.5) strength += 1;
      
      // 2. برخورد زیاد به EMA = ضعف روند
      if(touchCountEMA20 > 5)
      {
         int recentTouches = 0;
         for(int i = 0; i < ArraySize(touchesEMA20); i++)
         {
            if(currentTime - touchesEMA20[i].time < 24 * 3600) // 24 ساعت اخیر
               recentTouches++;
         }
         
         if(recentTouches > 3) strength -= 2;  // ضعف روند
      }
      
      return strength;
   }
   
   // تشخیص دبل باتن/تاپ روی EMA (نکته 110)
   bool IsDoubleTopBottomOnEMA(const MqlRates &candles[], int index, ENUM_SIGNAL_TYPE &signalType)
   {
      if(index < 20) return false;
      
      double ema20 = GetEMA20(0);
      double currentHigh = candles[index].high;
      double currentLow = candles[index].low;
      
      // جستجوی سقف دوقلو روی EMA
      for(int i = 5; i <= 20; i++)
      {
         if(index - i < 0) break;
         
         double prevHigh = candles[index - i].high;
         double prevLow = candles[index - i].low;
         
         // سقف دوقلو روی EMA
         if(MathAbs(currentHigh - prevHigh) < currentHigh * 0.001 &&
            MathAbs(currentHigh - ema20) < ema20 * 0.002)
         {
            signalType = SIGNAL_DOUBLE_TOP;
            return true;
         }
         
         // کف دوقلو روی EMA
         if(MathAbs(currentLow - prevLow) < currentLow * 0.001 &&
            MathAbs(currentLow - ema20) < ema20 * 0.002)
         {
            signalType = SIGNAL_DOUBLE_BOTTOM;
            return true;
         }
      }
      
      return false;
   }
   
   // پیشنهاد حد سود بر اساس EMA50 (نکته 23)
   double SuggestTakeProfitWithEMA50(double entryPrice, bool isLong)
   {
      double ema50 = GetEMA50(0);
      if(ema50 == 0) return 0;
      
      if(isLong)
      {
         // در روند صعودی، EMA50 حد سود
         if(entryPrice < ema50)
            return ema50 * 0.999;  // کمی پایینتر
      }
      else
      {
         // در روند نزولی، EMA50 حد سود
         if(entryPrice > ema50)
            return ema50 * 1.001;  // کمی بالاتر
      }
      
      return 0;
   }
   
   // تشخیص تاید روی EMA (نکات 78، 79، 81)
   bool IsTightRangeOnEMA(const MqlRates &candles[], int startIdx, int endIdx)
   {
      if(endIdx - startIdx < 5) return false;
      
      double ema20 = GetEMA20(0);
      int touchCount = 0;
      double maxDistance = 0;
      
      for(int i = startIdx; i <= endIdx; i++)
      {
         double distance = MathAbs(candles[i].close - ema20) / ema20 * 100;
         if(distance > maxDistance) maxDistance = distance;
         
         // آیا کندل EMA را لمس کرده؟
         if(candles[i].low <= ema20 && candles[i].high >= ema20)
            touchCount++;
      }
      
      // تاید: فاصله کم از EMA و برخورد مکرر
      return (maxDistance < 0.3 && touchCount >= 3);
   }
};