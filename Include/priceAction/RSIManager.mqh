//+------------------------------------------------------------------+
//|                                                      RSIManager.mqh |
//|                                        تشخیص واگرایی RSI برای برگشت روند |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"

enum ENUM_DIVERGENCE_TYPE
{
   DIV_NONE,
   DIV_BULLISH,        // واگرایی مثبت - کف پایینتر، RSI کف بالاتر
   DIV_BEARISH,        // واگرایی منفی - سقف بالاتر، RSI سقف پایینتر
   DIV_HIDDEN_BULLISH, // واگرایی مثبت پنهان - کف بالاتر، RSI کف پایینتر
   DIV_HIDDEN_BEARISH  // واگرایی منفی پنهان - سقف پایینتر، RSI سقف بالاتر
};

struct RSIData
{
   double            value;
   datetime          time;
   int               barIndex;
};

struct DivergenceSignal
{
   ENUM_DIVERGENCE_TYPE type;
   datetime          startTime;
   datetime          endTime;
   double            priceStart;
   double            priceEnd;
   double            rsiStart;
   double            rsiEnd;
   int               strength;      // 1-5
   bool              isValid;
};

class RSIManager
{
private:
   int               handleRSI;
   double            rsiBuffer[];
   int               rsiPeriod;
   double            overboughtLevel;
   double            oversoldLevel;
   
public:
   RSIManager()
   {
      handleRSI = INVALID_HANDLE;
      rsiPeriod = 14;
      overboughtLevel = 70;
      oversoldLevel = 30;
      ArraySetAsSeries(rsiBuffer, true);
   }
   
   ~RSIManager()
   {
      if(handleRSI != INVALID_HANDLE) IndicatorRelease(handleRSI);
   }
   
   bool InitializeRSI()
   {
      handleRSI = iRSI(_Symbol, InpEntryTimeframe, rsiPeriod, PRICE_CLOSE);
      
      if(handleRSI == INVALID_HANDLE)
      {
         Print("خطا در ایجاد اندیکاتور RSI");
         return false;
      }
      
      Print("RSI با موفقیت راه‌اندازی شد");
      return true;
   }
   
   bool RefreshRSI()
   {
      if(handleRSI == INVALID_HANDLE) return false;
      
      if(CopyBuffer(handleRSI, 0, 0, 100, rsiBuffer) < 50) return false;
      
      return true;
   }
   
   double GetRSI(int shift = 0)
   {
      if(ArraySize(rsiBuffer) > shift)
         return rsiBuffer[shift];
      return 50;
   }
   
   // تشخیص اشباع خرید/فروش
   bool IsOverbought(int shift = 0)
   {
      return (GetRSI(shift) > overboughtLevel);
   }
   
   bool IsOversold(int shift = 0)
   {
      return (GetRSI(shift) < oversoldLevel);
   }
   
   // تشخیص واگرایی (نکات 35 و 57)
   DivergenceSignal DetectDivergence(const MqlRates &candles[], int index, int lookback = 30)
   {
      DivergenceSignal div;
      div.type = DIV_NONE;
      div.isValid = false;
      
      if(index < lookback) return div;
      
      // پیدا کردن سقف‌ها و کف‌های قیمت
      double priceHighs[], priceLows[];
      double rsiHighs[], rsiLows[];
      int priceHighIndices[], priceLowIndices[];
      
      for(int i = index - lookback; i <= index; i++)
      {
         if(i < 2) continue;
         
         // سقف قیمت
         if(candles[i].high > candles[i-1].high && candles[i].high > candles[i+1].high)
         {
            ArrayResize(priceHighs, ArraySize(priceHighs) + 1);
            ArrayResize(rsiHighs, ArraySize(rsiHighs) + 1);
            ArrayResize(priceHighIndices, ArraySize(priceHighIndices) + 1);
            
            priceHighs[ArraySize(priceHighs)-1] = candles[i].high;
            rsiHighs[ArraySize(rsiHighs)-1] = GetRSI(i);
            priceHighIndices[ArraySize(priceHighIndices)-1] = i;
         }
         
         // کف قیمت
         if(candles[i].low < candles[i-1].low && candles[i].low < candles[i+1].low)
         {
            ArrayResize(priceLows, ArraySize(priceLows) + 1);
            ArrayResize(rsiLows, ArraySize(rsiLows) + 1);
            ArrayResize(priceLowIndices, ArraySize(priceLowIndices) + 1);
            
            priceLows[ArraySize(priceLows)-1] = candles[i].low;
            rsiLows[ArraySize(rsiLows)-1] = GetRSI(i);
            priceLowIndices[ArraySize(priceLowIndices)-1] = i;
         }
      }
      
      // بررسی واگرایی منفی (Bearish Divergence)
      if(ArraySize(priceHighs) >= 2)
      {
         for(int i = 0; i < ArraySize(priceHighs) - 1; i++)
         {
            if(priceHighs[i+1] > priceHighs[i] && rsiHighs[i+1] < rsiHighs[i])
            {
               div.type = DIV_BEARISH;
               div.startTime = candles[priceHighIndices[i]].time;
               div.endTime = candles[priceHighIndices[i+1]].time;
               div.priceStart = priceHighs[i];
               div.priceEnd = priceHighs[i+1];
               div.rsiStart = rsiHighs[i];
               div.rsiEnd = rsiHighs[i+1];
               div.strength = 5;
               div.isValid = true;
               Print("واگرایی منفی تشخیص داده شد - بازگشت به پایین");
               return div;
            }
         }
      }
      
      // بررسی واگرایی مثبت (Bullish Divergence)
      if(ArraySize(priceLows) >= 2)
      {
         for(int i = 0; i < ArraySize(priceLows) - 1; i++)
         {
            if(priceLows[i+1] < priceLows[i] && rsiLows[i+1] > rsiLows[i])
            {
               div.type = DIV_BULLISH;
               div.startTime = candles[priceLowIndices[i]].time;
               div.endTime = candles[priceLowIndices[i+1]].time;
               div.priceStart = priceLows[i];
               div.priceEnd = priceLows[i+1];
               div.rsiStart = rsiLows[i];
               div.rsiEnd = rsiLows[i+1];
               div.strength = 5;
               div.isValid = true;
               Print("واگرایی مثبت تشخیص داده شد - بازگشت به بالا");
               return div;
            }
         }
      }
      
      return div;
   }
   
   // تشخیص واگرایی پنهان (Hidden Divergence) - برای ادامه روند
   DivergenceSignal DetectHiddenDivergence(const MqlRates &candles[], int index, ENUM_TREND_DIRECTION trend)
   {
      DivergenceSignal div;
      div.type = DIV_NONE;
      div.isValid = false;
      
      if(trend == TREND_UP)
      {
         // واگرایی مثبت پنهان: کف بالاتر قیمت، کف پایینتر RSI
         // پیدا کردن دو کف
         // ... (برای اختصار، پیادهسازی کامل در نسخه نهایی)
      }
      
      return div;
   }
};