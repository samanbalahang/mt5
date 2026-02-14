//+------------------------------------------------------------------+
//|                                                 EntrySignalManager.mqh |
//|                                        مدیریت سیگنال‌های ورود (پینبار، انگالف، تایید) |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"

#include "CandleTypeDetector.mqh"
#include "TrendChannelDetector.mqh"
#include "SupportResistanceManager.mqh"

enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE,
   SIGNAL_PINBAR,           // پین بار
   SIGNAL_ENGULFING,        // انگالف
   SIGNAL_DOUBLE_TOP,       // سقف دوقلو
   SIGNAL_DOUBLE_BOTTOM,    // کف دوقلو
   SIGNAL_BREAKOUT_PULLBACK, // بریک‌اوت + پولبک
   SIGNAL_TRENDLINE_BREAK,  // شکست خط روند
   SIGNAL_CHANNEL_BREAK,    // شکست کانال
   SIGNAL_WEDGE_BREAK       // شکست ودج
};

enum ENUM_SIGNAL_CONFIRMATION
{
   CONFIRM_NONE,
   CONFIRM_CANDLE_CLOSE,    // بسته شدن کندل تأیید
   CONFIRM_BREAK_HIGH,      // شکست سقف قبلی
   CONFIRM_BREAK_LOW,       // شکست کف قبلی
   CONFIRM_PULLBACK        // پولبک به نقطه شکست
};

struct SignalBar
{
   ENUM_SIGNAL_TYPE      type;           // نوع سیگنال
   datetime              time;           // زمان سیگنال
   double                entryPrice;     // قیمت ورود
   double                stopLoss;       // حد ضرر
   double                takeProfit1;    // تی‌پی اول
   double                takeProfit2;    // تی‌پی دوم
   bool                  isLong;         // true = خرید، false = فروش
   int                   strength;       // قدرت سیگنال (1-5)
   bool                  confirmed;      // تأیید شده؟
   string                description;    // توضیحات
};

struct PullbackZone
{
   datetime              startTime;
   datetime              endTime;
   double                low;
   double                high;
   bool                  isValid;
};

class EntrySignalManager
{
private:
   CandleTypeDetector    candleDetector;
   TrendChannelDetector  trendDetector;
   SupportResistanceManager srManager;
   
   int                   maxLookback;
   double               minRiskReward;
   
public:
   EntrySignalManager()
   {
      maxLookback = 50;
      minRiskReward = 1.5;  // حداقل 1.5 ریسک به ریوارد
   }
   
   // تشخیص پین بار به عنوان سیگنال ورود
   SignalBar DetectPinBarSignal(const MqlRates &candles[], int index, 
                                ENUM_TREND_DIRECTION trend, bool expectReversal = false)
   {
      SignalBar signal;
      signal.type = SIGNAL_NONE;
      signal.confirmed = false;
      
      if(index < 1) return signal;
      
      MqlRates current = candles[index];
      MqlRates prev = candles[index - 1];
      
      bool isPinBar = candleDetector.IsPinBar(current, (trend == TREND_UP));
      
      if(!isPinBar) return signal;
      
      // پین بار در جهت روند یا خلاف روند؟
      bool pinBarBullish = (current.close > current.open);
      bool shouldBeLong = (pinBarBullish && (trend == TREND_UP || expectReversal));
      bool shouldBeShort = (!pinBarBullish && (trend == TREND_DOWN || expectReversal));
      
      if(shouldBeLong)
      {
         signal.type = SIGNAL_PINBAR;
         signal.time = current.time;
         signal.isLong = true;
         signal.entryPrice = current.high;  // ورود بالای شدو
         signal.stopLoss = current.low - (current.high - current.low) * 0.1; // زیر شدو
         signal.description = "پین بار صعودی در " + (expectReversal ? "ناحیه بازگشت" : "جهت روند");
         signal.strength = (candleDetector.BodyToRangeRatio(current) < 0.3) ? 4 : 3;
      }
      else if(shouldBeShort)
      {
         signal.type = SIGNAL_PINBAR;
         signal.time = current.time;
         signal.isLong = false;
         signal.entryPrice = current.low;   // ورود پایین شدو
         signal.stopLoss = current.high + (current.high - current.low) * 0.1; // بالای شدو
         signal.description = "پین بار نزولی در " + (expectReversal ? "ناحیه بازگشت" : "جهت روند");
         signal.strength = (candleDetector.BodyToRangeRatio(current) < 0.3) ? 4 : 3;
      }
      
      return signal;
   }
   
   // تشخیص انگالف (کندل خورنده)
   SignalBar DetectEngulfingSignal(const MqlRates &candles[], int index)
   {
      SignalBar signal;
      signal.type = SIGNAL_NONE;
      
      if(index < 1) return signal;
      
      MqlRates current = candles[index];
      MqlRates prev = candles[index - 1];
      
      if(!candleDetector.IsEngulfing(current, prev))
         return signal;
      
      // انگالف صعودی (خرید)
      if(current.close > current.open && prev.close < prev.open)
      {
         signal.type = SIGNAL_ENGULFING;
         signal.time = current.time;
         signal.isLong = true;
         signal.entryPrice = current.high;  // ورود بالای کندل
         signal.stopLoss = MathMin(prev.low, current.low) - 
                          (current.high - current.low) * 0.1;
         signal.description = "انگالف صعودی - برگشت به بالا";
         signal.strength = 4;
      }
      // انگالف نزولی (فروش)
      else if(current.close < current.open && prev.close > prev.open)
      {
         signal.type = SIGNAL_ENGULFING;
         signal.time = current.time;
         signal.isLong = false;
         signal.entryPrice = current.low;
         signal.stopLoss = MathMax(prev.high, current.high) + 
                          (current.high - current.low) * 0.1;
         signal.description = "انگالف نزولی - برگشت به پایین";
         signal.strength = 4;
      }
      
      return signal;
   }
   
   // تشخیص سقف/کف دوقلو
   SignalBar DetectDoubleTopBottom(const MqlRates &candles[], int index, int lookback = 20)
   {
      SignalBar signal;
      signal.type = SIGNAL_NONE;
      
      if(index < lookback) return signal;
      
      // پیدا کردن سقف‌ها و کف‌های محلی
      bool isSwingHigh = trendDetector.IsSwingHigh(candles, index, 2);
      bool isSwingLow = trendDetector.IsSwingLow(candles, index, 2);
      
      if(!isSwingHigh && !isSwingLow) return signal;
      
      double currentPrice = (isSwingHigh) ? candles[index].high : candles[index].low;
      
      // جستجوی سقف/کف مشابه در گذشته
      for(int i = index - 5; i >= index - lookback; i--)
      {
         if(i < 0) break;
         
         if(isSwingHigh && trendDetector.IsSwingHigh(candles, i, 2))
         {
            if(MathAbs(candles[i].high - currentPrice) < currentPrice * 0.001) // 0.1%
            {
               // سقف دوقلو - سیگنال فروش
               signal.type = SIGNAL_DOUBLE_TOP;
               signal.time = candles[index].time;
               signal.isLong = false;
               signal.entryPrice = candles[i].low; // ورود بعد از شکست
               signal.stopLoss = currentPrice * 1.01; // بالای سقف
               signal.description = "سقف دوقلو - انتظار ریزش";
               signal.strength = 5;
               break;
            }
         }
         
         if(isSwingLow && trendDetector.IsSwingLow(candles, i, 2))
         {
            if(MathAbs(candles[i].low - currentPrice) < currentPrice * 0.001)
            {
               // کف دوقلو - سیگنال خرید
               signal.type = SIGNAL_DOUBLE_BOTTOM;
               signal.time = candles[index].time;
               signal.isLong = true;
               signal.entryPrice = candles[i].high; // ورود بعد از شکست
               signal.stopLoss = currentPrice * 0.99; // پایین کف
               signal.description = "کف دوقلو - انتظار صعود";
               signal.strength = 5;
               break;
            }
         }
      }
      
      return signal;
   }
   
   // تشخیص کندل تأیید (Confirming Candle)
   bool IsConfirmationCandle(const MqlRates &candles[], int index, const SignalBar &signal)
   {
      if(index < 1) return false;
      
      MqlRates confirmCandle = candles[index];
      
      if(signal.isLong)
      {
         // کندل تأیید باید بالاتر از کندل سیگنال بسته شود
         if(confirmCandle.close > signal.entryPrice)
            return true;
         
         // انگالف خودش تأییدیه است
         if(candleDetector.IsEngulfing(confirmCandle, candles[index - 1]))
            return true;
      }
      else
      {
         // کندل تأیید باید پایین‌تر از کندل سیگنال بسته شود
         if(confirmCandle.close < signal.entryPrice)
            return true;
            
         if(candleDetector.IsEngulfing(confirmCandle, candles[index - 1]))
            return true;
      }
      
      return false;
   }
   
   // تشخیص پولبک
   PullbackZone DetectPullback(const MqlRates &candles[], int startIdx, int endIdx, 
                               ENUM_TREND_DIRECTION mainTrend)
   {
      PullbackZone zone;
      zone.isValid = false;
      
      if(endIdx - startIdx < 3) return zone;
      
      zone.startTime = candles[startIdx].time;
      zone.endTime = candles[endIdx].time;
      zone.low = DBL_MAX;
      zone.high = 0;
      
      int pullbackCount = 0;
      
      for(int i = startIdx; i <= endIdx; i++)
      {
         if(i > startIdx)
         {
            // پولبک پایین در روند صعودی
            if(mainTrend == TREND_UP && candles[i].low < candles[i-1].low)
               pullbackCount++;
            // پولبک بالا در روند نزولی
            if(mainTrend == TREND_DOWN && candles[i].high > candles[i-1].high)
               pullbackCount++;
         }
         
         if(candles[i].low < zone.low) zone.low = candles[i].low;
         if(candles[i].high > zone.high) zone.high = candles[i].high;
      }
      
      // اگر حداقل 60% کندل‌ها پولبک داشتند
      zone.isValid = (pullbackCount >= (endIdx - startIdx) * 0.6);
      
      return zone;
   }
   
   // تشخیص سیگنال روی پولبک به بریک‌اوت
   SignalBar DetectBreakoutPullbackSignal(const MqlRates &candles[], int index,
                                          double breakoutLevel, bool isBreakoutUp)
   {
      SignalBar signal;
      signal.type = SIGNAL_NONE;
      
      if(index < 2) return signal;
      
      // بررسی پولبک به سطح شکسته شده
      MqlRates current = candles[index];
      
      if(isBreakoutUp)  // بریک‌اوت به بالا
      {
         if(current.low <= breakoutLevel && current.close > breakoutLevel)
         {
            signal.type = SIGNAL_BREAKOUT_PULLBACK;
            signal.isLong = true;
            signal.entryPrice = current.high;
            signal.stopLoss = breakoutLevel * 0.995;
            signal.description = "پولبک به مقاومت شکسته شده - حمایت";
            signal.strength = 4;
         }
      }
      else  // بریک‌اوت به پایین
      {
         if(current.high >= breakoutLevel && current.close < breakoutLevel)
         {
            signal.type = SIGNAL_BREAKOUT_PULLBACK;
            signal.isLong = false;
            signal.entryPrice = current.low;
            signal.stopLoss = breakoutLevel * 1.005;
            signal.description = "پولبک به حمایت شکسته شده - مقاومت";
            signal.strength = 4;
         }
      }
      
      if(signal.type != SIGNAL_NONE)
         signal.time = current.time;
      
      return signal;
   }
   
   // محاسبه ریسک به ریوارد
   double CalculateRiskReward(const SignalBar &signal)
   {
      if(signal.stopLoss == 0 || signal.entryPrice == 0)
         return 0;
      
      double risk = MathAbs(signal.entryPrice - signal.stopLoss);
      
      if(signal.takeProfit1 > 0)
      {
         double reward = MathAbs(signal.takeProfit1 - signal.entryPrice);
         return (risk > 0) ? (reward / risk) : 0;
      }
      
      return 0;
   }
   
   // اعتبارسنجی نهایی سیگنال
   bool ValidateSignal(const SignalBar &signal, double currentPrice)
   {
      // 1. بررسی ریسک به ریوارد
      double rr = CalculateRiskReward(signal);
      if(rr < minRiskReward)
         return false;
      
      // 2. بررسی استاپ منطقی
      if(signal.isLong)
      {
         if(signal.stopLoss >= signal.entryPrice)
            return false;
      }
      else
      {
         if(signal.stopLoss <= signal.entryPrice)
            return false;
      }
      
      // 3. بررسی همپوشانی (در اسپایک اهمیتی ندارد)
      // این بخش در کامپوننت مدیریت ریسک کامل می‌شود
      
      return true;
   }
   
   // تشخیص بهترین سیگنال در بین چندین سیگنال
   SignalBar SelectBestSignal(SignalBar &signals[], int count)
   {
      SignalBar bestSignal;
      bestSignal.type = SIGNAL_NONE;
      
      int highestStrength = 0;
      
      for(int i = 0; i < count; i++)
      {
         if(signals[i].type != SIGNAL_NONE && signals[i].strength > highestStrength)
         {
            if(ValidateSignal(signals[i], signals[i].entryPrice))
            {
               bestSignal = signals[i];
               highestStrength = signals[i].strength;
            }
         }
      }
      
      return bestSignal;
   }
   
   // محاسبه حجم موقعیت بر اساس ریسک
   double CalculatePositionSize(double accountBalance, double riskPercent, 
                                double entryPrice, double stopLoss)
   {
      double riskAmount = accountBalance * (riskPercent / 100);
      double stopDistance = MathAbs(entryPrice - stopLoss);
      
      if(stopDistance == 0) return 0;
      
      // برای نمادهای مختلف نیاز به محاسبه ارزش تیک دارد
      // اینجا یک مقدار تقریبی برمی‌گردانیم
      return (riskAmount / stopDistance) * 0.01;  // مثال
   }
   
   // تشخیص کندل پولبک (زیر شدو بسته شود)
   bool IsPullbackCandle(const MqlRates &candle, const MqlRates &prevCandle, bool isUptrend)
   {
      if(isUptrend)
      {
         // پولبک پایین: حداقل یک کوچولو پایین‌تر از کندل قبلی
         return (candle.low < prevCandle.low);
      }
      else
      {
         // پولبک بالا: حداقل یک کوچولو بالاتر از کندل قبلی
         return (candle.high > prevCandle.high);
      }
   }
   
   // تشخیص اینکه آیا در فاز اسپایک هستیم یا خیر
   bool IsInSpikePhase(const MqlRates &candles[], int index)
   {
      return trendDetector.IsSpikePhase(candles, index, 4);
   }
   
   // توصیه برای ورود چند مرحله‌ای (20% سرمایه اولیه)
   double GetInitialEntrySize(double fullPositionSize)
   {
      return fullPositionSize * 0.2;  // 20% در ابتدا
   }
};