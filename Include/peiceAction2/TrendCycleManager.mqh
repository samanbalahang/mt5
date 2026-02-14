//+------------------------------------------------------------------+
//|                                                 TrendCycleManager.mqh |
//|                                        مدیریت روند و سایکل‌های بازار (اسپایک، کانال، رنج) |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"

#include "TrendChannelDetector.mqh"
#include "EntrySignalManager.mqh"

enum ENUM_CYCLE_PHASE
{
   PHASE_SPIKE,           // اسپایک - حرکت قوی یکطرفه
   PHASE_CHANNEL,         // کانال - ادامه روند با شیب کمتر
   PHASE_RANGE,           // تریدینگ رنج - پولبک بالا و پایین
   PHASE_PULLBACK,        // پولبک خالص
   PHASE_BREAKOUT,        // بریک‌اوت
   PHASE_RETEST,          // پولبک به نقطه شکست
   PHASE_CONTINUATION,    // ادامه روند
   PHASE_REVERSAL         // بازگشت روند
};

struct CycleInfo
{
   ENUM_CYCLE_PHASE      phase;           // فاز فعلی
   ENUM_TREND_DIRECTION  trend;           // جهت روند
   datetime              startTime;       // زمان شروع سایکل
   datetime              endTime;         // زمان پایان (اگر تمام شده)
   double                startPrice;      // قیمت شروع
   double                endPrice;        // قیمت پایان
   int                   legCount;        // تعداد لگ‌ها
   double                legSize;         // اندازه هر لگ
   bool                  isValid;         // اعتبار
};

struct WedgePattern
{
   bool                  isValid;
   bool                  isAscending;     // true = صعودی، false = نزولی
   datetime              startTime;
   datetime              endTime;
   double                upperLine1, upperLine2;  // نقاط خط بالایی
   double                lowerLine1, lowerLine2;  // نقاط خط پایینی
   int                   touches;         // تعداد برخورد
   ENUM_TREND_DIRECTION  priorTrend;      // روند قبل از ودج
   ENUM_TREND_DIRECTION  breakoutDirection; // جهت شکست
};

class TrendCycleManager
{
private:
   TrendChannelDetector  channelDetector;
   EntrySignalManager    signalManager;
   
   int                   minSpikeCandles;
   int                   maxCycleLookback;
   double               wedgeTolerance;
   
public:
   TrendCycleManager()
   {
      minSpikeCandles = 4;
      maxCycleLookback = 100;
      wedgeTolerance = 0.002;  // 0.2% برای تشخیص برخورد
   }
   
   // تشخیص فاز اسپایک
   CycleInfo DetectSpikePhase(const MqlRates &candles[], int index, int lookback = 10)
   {
      CycleInfo spike;
      spike.phase = PHASE_SPIKE;
      spike.isValid = false;
      
      if(index < lookback) return spike;
      
      // بررسی وجود اسپایک
      if(!channelDetector.IsSpikePhase(candles, index, minSpikeCandles))
         return spike;
      
      // تشخیص جهت اسپایک
      int upCount = 0, downCount = 0;
      for(int i = 0; i < minSpikeCandles; i++)
      {
         if(candles[index - i].close > candles[index - i].open)
            upCount++;
         else
            downCount++;
      }
      
      spike.trend = (upCount > downCount) ? TREND_UP : TREND_DOWN;
      spike.startTime = candles[index - minSpikeCandles + 1].time;
      spike.endTime = candles[index].time;
      spike.startPrice = (spike.trend == TREND_UP) ? 
                        candles[index - minSpikeCandles + 1].low :
                        candles[index - minSpikeCandles + 1].high;
      spike.endPrice = (spike.trend == TREND_UP) ?
                      candles[index].high :
                      candles[index].low;
      spike.legCount = 1;
      spike.legSize = MathAbs(spike.endPrice - spike.startPrice);
      spike.isValid = true;
      
      return spike;
   }
   
   // تشخیص فاز کانال
   CycleInfo DetectChannelPhase(const MqlRates &candles[], int startIdx, int endIdx)
   {
      CycleInfo channel;
      channel.phase = PHASE_CHANNEL;
      channel.isValid = false;
      
      Channel detectedChannel;
      if(!channelDetector.DetectChannel(candles, startIdx, endIdx, detectedChannel))
         return channel;
      
      // تشخیص روند کانال
      if(detectedChannel.upper.p1_price > detectedChannel.lower.p1_price)
      {
         // بررسی شیب
         if(detectedChannel.upper.p1_price > detectedChannel.upper.p2_price)
            channel.trend = TREND_DOWN;
         else if(detectedChannel.upper.p1_price < detectedChannel.upper.p2_price)
            channel.trend = TREND_UP;
         else
            channel.trend = TREND_SIDEWAYS;
      }
      
      channel.startTime = candles[startIdx].time;
      channel.endTime = candles[endIdx].time;
      channel.startPrice = (channel.trend == TREND_UP) ? 
                          detectedChannel.lower.p1_price : 
                          detectedChannel.upper.p1_price;
      channel.endPrice = (channel.trend == TREND_UP) ?
                        detectedChannel.upper.p2_price :
                        detectedChannel.lower.p2_price;
      channel.isValid = true;
      
      return channel;
   }
   
   // تشخیص فاز تریدینگ رنج
   CycleInfo DetectRangePhase(const MqlRates &candles[], int startIdx, int endIdx)
   {
      CycleInfo range;
      range.phase = PHASE_RANGE;
      range.trend = TREND_SIDEWAYS;
      range.isValid = false;
      
      if(!channelDetector.IsTradingRange(candles, startIdx, endIdx - startIdx))
         return range;
      
      // محاسبه کف و سقف رنج
      double rangeHigh = 0, rangeLow = DBL_MAX;
      
      for(int i = startIdx; i <= endIdx; i++)
      {
         if(candles[i].high > rangeHigh) rangeHigh = candles[i].high;
         if(candles[i].low < rangeLow) rangeLow = candles[i].low;
      }
      
      range.startTime = candles[startIdx].time;
      range.endTime = candles[endIdx].time;
      range.startPrice = rangeLow;
      range.endPrice = rangeHigh;
      range.legSize = rangeHigh - rangeLow;
      range.isValid = true;
      
      return range;
   }
   
   // تشخیص الگوی ودج (کنج)
   WedgePattern DetectWedge(const MqlRates &candles[], int startIdx, int endIdx)
   {
      WedgePattern wedge;
      wedge.isValid = false;
      
      if(endIdx - startIdx < 15) return wedge;
      
      // پیدا کردن سقف‌ها و کف‌های اصلی
      double swingHighs[], swingHighTimes[];
      double swingLows[], swingLowTimes[];
      
      for(int i = startIdx; i <= endIdx; i++)
      {
         if(channelDetector.IsSwingHigh(candles, i, 2))
         {
            ArrayResize(swingHighs, ArraySize(swingHighs) + 1);
            ArrayResize(swingHighTimes, ArraySize(swingHighTimes) + 1);
            swingHighs[ArraySize(swingHighs) - 1] = candles[i].high;
            swingHighTimes[ArraySize(swingHighTimes) - 1] = i;
         }
         
         if(channelDetector.IsSwingLow(candles, i, 2))
         {
            ArrayResize(swingLows, ArraySize(swingLows) + 1);
            ArrayResize(swingLowTimes, ArraySize(swingLowTimes) + 1);
            swingLows[ArraySize(swingLows) - 1] = candles[i].low;
            swingLowTimes[ArraySize(swingLowTimes) - 1] = i;
         }
      }
      
      // برای ودج حداقل ۳ سقف و ۳ کف نیاز داریم
      if(ArraySize(swingHighs) < 3 || ArraySize(swingLows) < 3)
         return wedge;
      
      // بررسی شیب سقف‌ها و کف‌ها
      double highSlope = 0, lowSlope = 0;
      
      if(ArraySize(swingHighs) >= 3)
      {
         highSlope = (swingHighs[ArraySize(swingHighs)-1] - swingHighs[0]) / 
                    (ArraySize(swingHighs) - 1);
      }
      
      if(ArraySize(swingLows) >= 3)
      {
         lowSlope = (swingLows[ArraySize(swingLows)-1] - swingLows[0]) / 
                   (ArraySize(swingLows) - 1);
      }
      
      // ودج صعودی: کف‌ها با شیب تندتر از سقف‌ها
      if(lowSlope > highSlope && highSlope < 0)
      {
         wedge.isValid = true;
         wedge.isAscending = true;  // صعودی
         wedge.upperLine1 = swingHighs[0];
         wedge.upperLine2 = swingHighs[ArraySize(swingHighs)-1];
         wedge.lowerLine1 = swingLows[0];
         wedge.lowerLine2 = swingLows[ArraySize(swingLows)-1];
         wedge.touches = ArraySize(swingHighs);
         wedge.breakoutDirection = TREND_DOWN;  // ودج صعودی به پایین میشکند
      }
      // ودج نزولی: سقف‌ها با شیب تندتر از کف‌ها
      else if(highSlope < lowSlope && lowSlope > 0)
      {
         wedge.isValid = true;
         wedge.isAscending = false; // نزولی
         wedge.upperLine1 = swingHighs[0];
         wedge.upperLine2 = swingHighs[ArraySize(swingHighs)-1];
         wedge.lowerLine1 = swingLows[0];
         wedge.lowerLine2 = swingLows[ArraySize(swingLows)-1];
         wedge.touches = ArraySize(swingHighs);
         wedge.breakoutDirection = TREND_UP;  // ودج نزولی به بالا میشکند
      }
      
      wedge.startTime = candles[startIdx].time;
      wedge.endTime = candles[endIdx].time;
      
      return wedge;
   }
   
   // تشخیص لگ‌های حرکتی (معمولاً دو لگ)
   int DetectLegs(const MqlRates &candles[], int startIdx, int endIdx, 
                  ENUM_TREND_DIRECTION trend, double &legSizes[])
   {
      int legCount = 0;
      ArrayResize(legSizes, 0);
      
      if(endIdx - startIdx < 10) return 0;
      
      bool lookingForHigh = (trend == TREND_UP);
      double lastExtreme = (lookingForHigh) ? 
                          candles[startIdx].low : 
                          candles[startIdx].high;
      
      for(int i = startIdx + 1; i <= endIdx; i++)
      {
         if(lookingForHigh)
         {
            if(channelDetector.IsSwingHigh(candles, i, 1))
            {
               double legSize = candles[i].high - lastExtreme;
               if(legSize > 0)
               {
                  ArrayResize(legSizes, ArraySize(legSizes) + 1);
                  legSizes[ArraySize(legSizes) - 1] = legSize;
                  legCount++;
                  lookingForHigh = false;
                  lastExtreme = candles[i].high;
               }
            }
         }
         else
         {
            if(channelDetector.IsSwingLow(candles, i, 1))
            {
               double legSize = lastExtreme - candles[i].low;
               if(legSize > 0)
               {
                  ArrayResize(legSizes, ArraySize(legSizes) + 1);
                  legSizes[ArraySize(legSizes) - 1] = legSize;
                  legCount++;
                  lookingForHigh = true;
                  lastExtreme = candles[i].low;
               }
            }
         }
      }
      
      return legCount;
   }
   
   // تشخیص قدرت روند بر اساس فاصله سقف و کف
   ENUM_TREND_STRENGTH AnalyzeTrendStrength(const MqlRates &candles[], int index)
   {
      if(index < 10) return STRENGTH_WEAK;
      
      double lastHigh = candles[index].high;
      double lastLow = candles[index].low;
      double prevHigh = 0, prevLow = 0;
      
      // پیدا کردن آخرین سقف و کف قبل
      for(int i = index - 1; i >= index - 20; i--)
      {
         if(i < 0) break;
         
         if(channelDetector.IsSwingHigh(candles, i, 2))
         {
            prevHigh = candles[i].high;
            break;
         }
      }
      
      for(int i = index - 1; i >= index - 20; i--)
      {
         if(i < 0) break;
         
         if(channelDetector.IsSwingLow(candles, i, 2))
         {
            prevLow = candles[i].low;
            break;
         }
      }
      
      ENUM_TREND_DIRECTION trend = channelDetector.DetectTrend(candles, index - 20, 20);
      
      if(trend == TREND_UP)
      {
         // روند بسیار قوی: کف فعلی سقف قبلی را سوراخ نکند
         if(prevHigh > 0 && lastLow > prevHigh)
            return STRENGTH_VERY_STRONG;
         
         // روند قوی: کف و سقف در یک ناحیه
         if(prevHigh > 0 && MathAbs(lastLow - prevHigh) < lastLow * 0.001)
            return STRENGTH_STRONG;
         
         // روند متوسط: کف سقف قبلی را سوراخ میکند
         if(prevHigh > 0 && lastLow < prevHigh)
            return STRENGTH_MEDIUM;
      }
      else if(trend == TREND_DOWN)
      {
         // روند بسیار قوی: سقف فعلی کف قبلی را سوراخ نکند
         if(prevLow > 0 && lastHigh < prevLow)
            return STRENGTH_VERY_STRONG;
         
         if(prevLow > 0 && MathAbs(lastHigh - prevLow) < lastHigh * 0.001)
            return STRENGTH_STRONG;
         
         if(prevLow > 0 && lastHigh > prevLow)
            return STRENGTH_MEDIUM;
      }
      
      return STRENGTH_WEAK;
   }
   
   // تشخیص برگشت روند (Reversal)
   bool IsReversal(const MqlRates &candles[], int index, int lookback = 30)
   {
      if(index < lookback) return false;
      
      ENUM_TREND_DIRECTION currentTrend = channelDetector.DetectTrend(candles, index - 10, 10);
      ENUM_TREND_DIRECTION priorTrend = channelDetector.DetectTrend(candles, index - lookback, 20);
      
      if(currentTrend == TREND_UNDEFINED || priorTrend == TREND_UNDEFINED)
         return false;
      
      // برگشت از صعودی به نزولی
      if(priorTrend == TREND_UP && currentTrend == TREND_DOWN)
      {
         // بررسی سقف پایین‌تر (LH)
         bool hasLowerHigh = false;
         for(int i = index - 10; i < index; i++)
         {
            if(channelDetector.IsSwingHigh(candles, i, 2))
            {
               double currentHigh = candles[i].high;
               for(int j = i - 10; j < i; j++)
               {
                  if(j >= 0 && channelDetector.IsSwingHigh(candles, j, 2))
                  {
                     if(currentHigh < candles[j].high)
                        hasLowerHigh = true;
                     break;
                  }
               }
            }
         }
         
         if(hasLowerHigh)
            return true;
      }
      
      // برگشت از نزولی به صعودی
      if(priorTrend == TREND_DOWN && currentTrend == TREND_UP)
      {
         // بررسی کف بالاتر (HL)
         bool hasHigherLow = false;
         for(int i = index - 10; i < index; i++)
         {
            if(channelDetector.IsSwingLow(candles, i, 2))
            {
               double currentLow = candles[i].low;
               for(int j = i - 10; j < i; j++)
               {
                  if(j >= 0 && channelDetector.IsSwingLow(candles, j, 2))
                  {
                     if(currentLow > candles[j].low)
                        hasHigherLow = true;
                     break;
                  }
               }
            }
         }
         
         if(hasHigherLow)
            return true;
      }
      
      return false;
   }
   
   // تشخیص میکروترند (چند کندل کوچک پشت سر هم)
   bool IsMicroTrend(const MqlRates &candles[], int index, int minCandles = 5)
   {
      if(index < minCandles) return false;
      
      bool isUp = true;
      int upCount = 0, downCount = 0;
      
      for(int i = 0; i < minCandles; i++)
      {
         if(candles[index - i].close > candles[index - i].open)
            upCount++;
         else
            downCount++;
      }
      
      if(upCount >= minCandles - 1)
      {
         // بررسی لوی‌های بالاتر
         for(int i = 1; i < minCandles; i++)
         {
            if(candles[index - i].high <= candles[index - i + 1].high)
               return false;
         }
         return true;
      }
      else if(downCount >= minCandles - 1)
      {
         for(int i = 1; i < minCandles; i++)
         {
            if(candles[index - i].low >= candles[index - i + 1].low)
               return false;
         }
         return true;
      }
      
      return false;
   }
   
   // تشخیص سایکل کلی بازار
   CycleInfo GetCurrentCycle(const MqlRates &candles[], int index, int lookback = 30)
   {
      CycleInfo currentCycle;
      currentCycle.isValid = false;
      
      if(index < lookback) return currentCycle;
      
      // 1. اول بررسی اسپایک
      CycleInfo spike = DetectSpikePhase(candles, index, 10);
      if(spike.isValid)
      {
         currentCycle = spike;
         return currentCycle;
      }
      
      // 2. بررسی رنج
      if(channelDetector.IsTradingRange(candles, index - lookback, lookback))
      {
         currentCycle = DetectRangePhase(candles, index - lookback, index);
         return currentCycle;
      }
      
      // 3. بررسی کانال
      Channel channel;
      if(channelDetector.DetectChannel(candles, index - lookback, index, channel))
      {
         currentCycle = DetectChannelPhase(candles, index - lookback, index);
         return currentCycle;
      }
      
      return currentCycle;
   }
   
   // پیشنهاد حد سود بر اساس سایکل
   double SuggestTakeProfitByCycle(const CycleInfo &cycle, double entryPrice, bool isLong)
   {
      if(!cycle.isValid) return 0;
      
      switch(cycle.phase)
      {
         case PHASE_SPIKE:
            // در اسپایک، تی‌پی می‌تواند انتهای کانال بعدی باشد
            return (isLong) ? cycle.endPrice * 1.02 : cycle.endPrice * 0.98;
            
         case PHASE_CHANNEL:
            // در کانال، تی‌پی خط مقابل کانال
            if(isLong)
               return (cycle.trend == TREND_UP) ? cycle.endPrice : cycle.startPrice;
            else
               return (cycle.trend == TREND_DOWN) ? cycle.endPrice : cycle.startPrice;
            
         case PHASE_RANGE:
            // در رنج، تی‌پی سقف/کف رنج
            return (isLong) ? cycle.endPrice : cycle.startPrice;
            
         default:
            return 0;
      }
   }
};