//+------------------------------------------------------------------+
//|                                                   PatternDetector.mqh |
//|                                        تشخیص الگوهای فلگ، مثلث، هد اند شولدر |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"

#include "TrendChannelDetector.mqh"

enum ENUM_PATTERN_TYPE
{
   PATTERN_NONE,
   PATTERN_FLAG_BULL,      // فلگ صعودی
   PATTERN_FLAG_BEAR,      // فلگ نزولی
   PATTERN_PENNANT,        // پرچم
   PATTERN_TRIANGLE_SYM,   // مثلث متقارن
   PATTERN_TRIANGLE_ASC,   // مثلث صعودی
   PATTERN_TRIANGLE_DESC,  // مثلث نزولی
   PATTERN_HS_TOP,         // هد اند شولدر سقف
   PATTERN_HS_BOTTOM,      // هد اند شولدر کف
   PATTERN_RECTANGLE,      // مستطیل
   PATTERN_BARBED_WIRE     // سیم خاردار (تاید)
};

struct PatternInfo
{
   ENUM_PATTERN_TYPE   type;
   datetime            startTime;
   datetime            endTime;
   double              entryPrice;
   double              stopLoss;
   double              takeProfit;
   double              height;        // ارتفاع الگو
   bool                isBullish;
   int                 strength;
   string              description;
   bool                isValid;
};

class PatternDetector
{
private:
   TrendChannelDetector  trendDetector;
   int                   minPatternBars;
   
public:
   PatternDetector()
   {
      minPatternBars = 10;
   }
   
   // تشخیص الگوی فلگ (نکات 32 و 64)
   PatternInfo DetectFlag(const MqlRates &candles[], int index, ENUM_TREND_DIRECTION priorTrend)
   {
      PatternInfo pattern;
      pattern.type = PATTERN_NONE;
      pattern.isValid = false;
      
      if(index < 20) return pattern;
      
      // تشخیص اسپایک قبل از فلگ
      bool hasSpike = false;
      double spikeHigh = 0, spikeLow = 0;
      
      for(int i = 5; i <= 15; i++)
      {
         if(index - i < 0) break;
         
         if(trendDetector.IsSpikePhase(candles, index - i, 4))
         {
            hasSpike = true;
            spikeHigh = candles[index - i].high;
            spikeLow = candles[index - i].low;
            break;
         }
      }
      
      if(!hasSpike) return pattern;
      
      // بررسی فلگ (حرکت خلاف جهت با شیب کم)
      int flagStart = index - 10;
      int flagEnd = index;
      
      double flagHigh = 0, flagLow = DBL_MAX;
      bool isCounterTrend = false;
      
      for(int i = flagStart; i <= flagEnd; i++)
      {
         if(candles[i].high > flagHigh) flagHigh = candles[i].high;
         if(candles[i].low < flagLow) flagLow = candles[i].low;
      }
      
      if(priorTrend == TREND_UP)
      {
         // فلگ در روند صعودی: اصلاح به پایین
         isCounterTrend = (flagLow < spikeHigh * 0.99);
         
         if(isCounterTrend && (flagHigh - flagLow) < (spikeHigh - spikeLow) * 0.3)
         {
            pattern.type = PATTERN_FLAG_BULL;
            pattern.isBullish = true;
            pattern.startTime = candles[flagStart].time;
            pattern.endTime = candles[flagEnd].time;
            pattern.height = spikeHigh - spikeLow;  // ارتفاع میله پرچم
            pattern.entryPrice = flagHigh;          // ورود بالای فلگ
            pattern.stopLoss = flagLow * 0.995;     // زیر فلگ
            pattern.takeProfit = flagHigh + pattern.height;  // اندازه میله پرچم
            pattern.strength = 4;
            pattern.description = "فلگ صعودی - ادامه روند";
            pattern.isValid = true;
            
            Print("فلگ صعودی تشخیص داده شد - اندازه حرکت هدف: ", pattern.height);
         }
      }
      else if(priorTrend == TREND_DOWN)
      {
         // فلگ در روند نزولی: اصلاح به بالا
         isCounterTrend = (flagHigh > spikeLow * 1.01);
         
         if(isCounterTrend && (flagHigh - flagLow) < (spikeHigh - spikeLow) * 0.3)
         {
            pattern.type = PATTERN_FLAG_BEAR;
            pattern.isBullish = false;
            pattern.startTime = candles[flagStart].time;
            pattern.endTime = candles[flagEnd].time;
            pattern.height = spikeHigh - spikeLow;
            pattern.entryPrice = flagLow;           // ورود زیر فلگ
            pattern.stopLoss = flagHigh * 1.005;    // بالای فلگ
            pattern.takeProfit = flagLow - pattern.height;
            pattern.strength = 4;
            pattern.description = "فلگ نزولی - ادامه روند";
            pattern.isValid = true;
            
            Print("فلگ نزولی تشخیص داده شد - اندازه حرکت هدف: ", pattern.height);
         }
      }
      
      return pattern;
   }
   
   // تشخیص الگوی مثلث (نکات 37، 62، 101)
   PatternInfo DetectTriangle(const MqlRates &candles[], int startIdx, int endIdx)
   {
      PatternInfo pattern;
      pattern.type = PATTERN_NONE;
      pattern.isValid = false;
      
      if(endIdx - startIdx < 15) return pattern;
      
      // پیدا کردن سقف‌ها و کف‌ها
      double highs[], lows[];
      int highIndices[], lowIndices[];
      
      for(int i = startIdx; i <= endIdx; i++)
      {
         if(trendDetector.IsSwingHigh(candles, i, 2))
         {
            ArrayResize(highs, ArraySize(highs) + 1);
            ArrayResize(highIndices, ArraySize(highIndices) + 1);
            highs[ArraySize(highs)-1] = candles[i].high;
            highIndices[ArraySize(highIndices)-1] = i;
         }
         
         if(trendDetector.IsSwingLow(candles, i, 2))
         {
            ArrayResize(lows, ArraySize(lows) + 1);
            ArrayResize(lowIndices, ArraySize(lowIndices) + 1);
            lows[ArraySize(lows)-1] = candles[i].low;
            lowIndices[ArraySize(lowIndices)-1] = i;
         }
      }
      
      if(ArraySize(highs) < 3 || ArraySize(lows) < 3) return pattern;
      
      // محاسبه شیب سقف‌ها و کف‌ها
      double highSlope = (highs[ArraySize(highs)-1] - highs[0]) / (ArraySize(highs) - 1);
      double lowSlope = (lows[ArraySize(lows)-1] - lows[0]) / (ArraySize(lows) - 1);
      
      double highAngle = MathArctan(highSlope) * 180 / M_PI;
      double lowAngle = MathArctan(lowSlope) * 180 / M_PI;
      
      // مثلث متقارن
      if(MathAbs(highAngle + lowAngle) < 10)  // سقف نزولی، کف صعودی
      {
         pattern.type = PATTERN_TRIANGLE_SYM;
         pattern.isBullish = (candles[endIdx].close > highs[ArraySize(highs)-1] * 0.95);
         pattern.height = highs[0] - lows[0];
         pattern.entryPrice = pattern.isBullish ? highs[ArraySize(highs)-1] : lows[ArraySize(lows)-1];
         pattern.takeProfit = pattern.isBullish ? pattern.entryPrice + pattern.height : 
                                                  pattern.entryPrice - pattern.height;
         pattern.isValid = true;
         pattern.description = "مثلث متقارن - شکست به " + (pattern.isBullish ? "بالا" : "پایین");
      }
      // مثلث صعودی (سقف صاف، کف صعودی)
      else if(MathAbs(highSlope) < 0.1 && lowSlope > 0.1)
      {
         pattern.type = PATTERN_TRIANGLE_ASC;
         pattern.isBullish = true;
         pattern.height = highs[0] - lows[0];
         pattern.entryPrice = highs[ArraySize(highs)-1];
         pattern.takeProfit = pattern.entryPrice + pattern.height;
         pattern.isValid = true;
         pattern.description = "مثلث صعودی - شکست به بالا";
      }
      // مثلث نزولی (کف صاف، سقف نزولی)
      else if(MathAbs(lowSlope) < 0.1 && highSlope < -0.1)
      {
         pattern.type = PATTERN_TRIANGLE_DESC;
         pattern.isBullish = false;
         pattern.height = highs[0] - lows[0];
         pattern.entryPrice = lows[ArraySize(lows)-1];
         pattern.takeProfit = pattern.entryPrice - pattern.height;
         pattern.isValid = true;
         pattern.description = "مثلث نزولی - شکست به پایین";
      }
      
      if(pattern.isValid)
      {
         pattern.startTime = candles[startIdx].time;
         pattern.endTime = candles[endIdx].time;
         pattern.stopLoss = pattern.isBullish ? lows[0] * 0.99 : highs[0] * 1.01;
         pattern.strength = 4;
      }
      
      return pattern;
   }
   
   // تشخیص الگوی هد اند شولدر (نکات 41 و 25 الگوها)
   PatternInfo DetectHeadAndShoulders(const MqlRates &candles[], int index, int lookback = 40)
   {
      PatternInfo pattern;
      pattern.type = PATTERN_NONE;
      pattern.isValid = false;
      
      if(index < lookback) return pattern;
      
      // پیدا کردن سه سقف با سقف میانی بالاتر
      double peaks[];
      int peakIndices[];
      
      for(int i = index - lookback; i <= index; i++)
      {
         if(trendDetector.IsSwingHigh(candles, i, 3))
         {
            ArrayResize(peaks, ArraySize(peaks) + 1);
            ArrayResize(peakIndices, ArraySize(peakIndices) + 1);
            peaks[ArraySize(peaks)-1] = candles[i].high;
            peakIndices[ArraySize(peakIndices)-1] = i;
         }
      }
      
      if(ArraySize(peaks) < 3) return pattern;
      
      // بررسی هد اند شولدر سقف
      for(int i = 0; i < ArraySize(peaks) - 2; i++)
      {
         // شانه چپ، سر، شانه راست
         if(peaks[i+1] > peaks[i] && peaks[i+1] > peaks[i+2] &&
            MathAbs(peaks[i] - peaks[i+2]) < (peaks[i+1] - peaks[i]) * 0.3)
         {
            // پیدا کردن خط گردن (نک لاین)
            double neckline = MathMin(candles[peakIndices[i]].low, candles[peakIndices[i+2]].low);
            
            pattern.type = PATTERN_HS_TOP;
            pattern.isBullish = false;
            pattern.startTime = candles[peakIndices[i]].time;
            pattern.endTime = candles[peakIndices[i+2]].time;
            pattern.height = peaks[i+1] - neckline;
            pattern.entryPrice = neckline * 0.995;  // زیر خط گردن
            pattern.stopLoss = peaks[i+1] * 1.005;  // بالای سر
            pattern.takeProfit = pattern.entryPrice - pattern.height;  // اندازه قد
            pattern.strength = 5;
            pattern.description = "هد اند شولدر سقف - بازگشت به پایین";
            pattern.isValid = true;
            
            Print("هد اند شولدر سقف تشخیص داده شد - هدف: ", pattern.takeProfit);
            return pattern;
         }
      }
      
      return pattern;
   }
   
   // تشخیص الگوی سیم خاردار / تاید (نکات 77-83)
   PatternInfo DetectBarbedWire(const MqlRates &candles[], int startIdx, int endIdx)
   {
      PatternInfo pattern;
      pattern.type = PATTERN_NONE;
      pattern.isValid = false;
      
      if(endIdx - startIdx < 8) return pattern;
      
      int smallBodies = 0;
      int longShadows = 0;
      double avgBodySize = 0;
      
      for(int i = startIdx; i <= endIdx; i++)
      {
         double body = MathAbs(candles[i].close - candles[i].open);
         double range = candles[i].high - candles[i].low;
         double shadowRatio = (range - body) / range;
         
         avgBodySize += body;
         
         if(body < range * 0.2) smallBodies++;
         if(shadowRatio > 0.6) longShadows++;
      }
      
      avgBodySize /= (endIdx - startIdx + 1);
      
      // سیم خاردار: بدنه‌های کوچک، شدوهای بلند
      if(smallBodies >= (endIdx - startIdx) * 0.6 && longShadows >= 3)
      {
         pattern.type = PATTERN_BARBED_WIRE;
         pattern.startTime = candles[startIdx].time;
         pattern.endTime = candles[endIdx].time;
         pattern.isValid = true;
         pattern.description = "الگوی سیم خاردار - آماده شکست";
         
         // تشخیص جهت شکست
         double lastClose = candles[endIdx].close;
         double ema20 = 0; // باید از خارج دریافت شود
         
         if(lastClose > ema20)
            pattern.isBullish = true;
         else
            pattern.isBullish = false;
            
         Print("الگوی سیم خاردار تشخیص داده شد - آماده شکست به ", 
               pattern.isBullish ? "بالا" : "پایین");
      }
      
      return pattern;
   }
   
   // تشخیص الگوی مستطیل (نکته 36)
   PatternInfo DetectRectangle(const MqlRates &candles[], int startIdx, int endIdx)
   {
      PatternInfo pattern;
      pattern.type = PATTERN_NONE;
      pattern.isValid = false;
      
      if(endIdx - startIdx < 15) return pattern;
      
      double rangeHigh = 0, rangeLow = DBL_MAX;
      int touchHigh = 0, touchLow = 0;
      
      for(int i = startIdx; i <= endIdx; i++)
      {
         if(candles[i].high > rangeHigh) rangeHigh = candles[i].high;
         if(candles[i].low < rangeLow) rangeLow = candles[i].low;
      }
      
      // شمارش برخوردها به سقف و کف
      for(int i = startIdx; i <= endIdx; i++)
      {
         if(MathAbs(candles[i].high - rangeHigh) < rangeHigh * 0.001)
            touchHigh++;
         if(MathAbs(candles[i].low - rangeLow) < rangeLow * 0.001)
            touchLow++;
      }
      
      // مستطیل معتبر: حداقل 2 برخورد به هر طرف
      if(touchHigh >= 2 && touchLow >= 2)
      {
         pattern.type = PATTERN_RECTANGLE;
         pattern.startTime = candles[startIdx].time;
         pattern.endTime = candles[endIdx].time;
         pattern.height = rangeHigh - rangeLow;
         pattern.isValid = true;
         pattern.description = "الگوی مستطیل - ادامه روند قبلی";
         
         Print("الگوی مستطیل تشخیص داده شد - ارتفاع: ", pattern.height);
      }
      
      return pattern;
   }
};