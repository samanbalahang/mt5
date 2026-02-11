//+------------------------------------------------------------------+
//| ElliottWaveRobot
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System"
#property version   "8.2"
#property strict
#property description "H4 Trendline Breakout + Multi-Timeframe + Elliott Wave + Fibonacci"
#property description "استاپ بر اساس دم کندل M15 + تریلینگ هوشمند الیوت"

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>

CTrade trade;
CPositionInfo position;
CHistoryOrderInfo history;

//================ INPUT PARAMETERS ================
// بخش 1: تنظیمات تشخیص خط روند
input string   SECTION1 = "=== TRENDLINE DETECTION SETTINGS ===";
input int      LookbackPeriod      = 150;    // تعداد کندل‌های بررسی
input int      SwingPointsLookback = 60;     // تعداد کندل برای یافتن سوینگ‌ها
input double   MinTrendlineAngle   = 8.0;    // حداقل زاویه خط روند (درجه)
input int      BreakoutConfirmationBars = 2; // کندل‌های تأیید شکست
input double   BreakoutThreshold   = 0.0008; // حداقل شکست (8 پیپ)
input double   VolumeSpikeFactor   = 1.3;    // ضریب افزایش حجم برای شکست

// بخش 2: تنظیمات RSI
input string   SECTION2 = "=== RSI SETTINGS ===";
input int      RSI_Period          = 14;     // دوره RSI
input double   RSI_Overbought      = 65.0;   // سطح اشباع خرید
input double   RSI_Oversold        = 35.0;   // سطح اشباع فروش
input bool     UseRSIConfirmation  = true;   // فعال کردن فیلتر RSI
input int      RSI_Lookback        = 20;     // بررسی برای واگرایی

// بخش 3: تنظیمات چند تایم‌فریم
input string   SECTION3 = "=== MULTI-TIMEFRAME SETTINGS ===";
input bool     UseH1_Confirmation = true;    // تایید در تایم‌فریم H1
input bool     UseM15_Entry = true;          // ورود در تایم‌فریم M15
input int      MaxWaitForEntry = 12;         // حداکثر انتظار برای ورود (ساعت)

// بخش 4: تنظیمات فیبوناچی
input string   SECTION4 = "=== FIBONACCI SETTINGS ===";
input bool     UseMultipleTPs = true;        // استفاده از چندین TP
input double   Fibo_TP1 = 0.236;             // TP اول (23.6%)
input double   Fibo_TP2 = 0.382;             // TP دوم (38.2%)
input double   Fibo_TP3 = 0.618;             // TP سوم (61.8%)
input double   Fibo_TP4 = 1.0;               // TP چهارم (100%)
input double   TP1_Percentage = 30;          // درصد حجم برای TP1
input double   TP2_Percentage = 30;          // درصد حجم برای TP2
input double   TP3_Percentage = 25;          // درصد حجم برای TP3
input double   TP4_Percentage = 15;          // درصد حجم برای TP4

// بخش 5: تنظیمات الیوت و تریلینگ
input string   SECTION5 = "=== ELLIOTT WAVE & TRAILING SETTINGS ===";
input bool     UseElliottWaveDetection = true;  // تشخیص امواج الیوت
input bool     UseWaveTrailing = true;          // تریلینگ بر اساس الیوت
input double   Wave1_TrailPercent = 30;         // درصد موج 1 (بریک ایون)
input double   Wave3_TrailPercent = 50;         // درصد موج 3 (تریل ملایم)
input double   Wave5_TrailPercent = 70;         // درصد موج 5 (تریل محکم)
input int      MinWaveBarsForTrail = 5;         // حداقل کندل برای تشکیل موج
input double   BreakevenPercent = 50;           // درصد ریسک برای بریک ایون (50%)

// بخش 6: تنظیمات ورود M15 و استاپ بر اساس دم کندل
input string   SECTION6 = "=== M15 ENTRY & STOP LOSS SETTINGS ===";
input int      M15_RSI_Period = 9;              // RSI سریع برای M15
input double   M15_RSI_Entry = 40;              // سطح RSI برای ورود در پولبک
input bool     WaitForPullback = true;          // منتظر پولبک بمان
input int      MaxPullbackBars = 10;            // حداکثر کندل برای پولبک
input double   PullbackDepth = 0.382;           // عمق پولبک فیبوناچی
input bool     UseCandleBasedSL = true;         // استاپ بر اساس دم کندل
input int      SL_WickOffset = 2;               // فاصله از دم کندل (پیپ)
input double   SL_BufferPercent = 10;           // درصد بافر از ارتفاع کندل

// بخش 7: تنظیمات مدیریت ریسک
input string   SECTION7 = "=== RISK MANAGEMENT ===";
input double   RiskPercent        = 1.0;        // درصد ریسک هر معامله
input double   MinLotSize         = 0.01;       // حداقل حجم
input double   MaxLotSize         = 1.0;        // حداکثر حجم
input int      StopLossPips       = 40;         // حد ضرر اولیه (پیپ)
input int      TakeProfitPips     = 80;         // حد سود (پیپ)
input bool     UseATR_SL_TP       = true;       // استفاده از ATR
input double   ATR_SL_Multiplier  = 1.5;        // ضریب ATR برای حد ضرر
input double   ATR_TP_Multiplier  = 3.0;        // ضریب ATR برای حد سود

// بخش 8: تنظیمات نمایش
input string   SECTION8 = "=== DISPLAY SETTINGS ===";
input bool     EnableAlerts       = true;
input bool     DrawTrendlines     = true;
input color    EURUSD_UptrendColor = clrDodgerBlue;
input color    EURUSD_DowntrendColor = clrCrimson;

//================ STRUCTURES ================
// ساختار خط روند
struct TrendLine
{
   double   startPrice;
   double   endPrice;
   int      startBar;
   int      endBar;
   bool     isUpTrend;
   double   slope;
   double   angle;
   int      touchCount;
   datetime lastBreakTime;
   string   trendlineName;
   double   currentValue;
};

// ساختار سیگنال تجاری (بهبود یافته با فیلدهای جدید)
struct TradeSignal
{
   bool        isValid;
   bool        isBuy;
   double      h4_BreakPrice;
   datetime    signalTime;
   double      h1_ConfirmationPrice;
   datetime    h1_ConfirmationTime;
   double      fibonacciLevels[5];
   double      waveStartPrice;
   int         currentWave;
   double      trailingStop;
   double      tpLevels[4];
   bool        tpHit[4];
   double      tpPercentages[4];
   
   // فیلدهای جدید برای استاپ بر اساس دم کندل
   double      entryCandleLow;
   double      entryCandleHigh;
   double      entryCandleClose;
   datetime    entryCandleTime;
   double      initialStopLoss;
   double      breakEvenActivated;
};

// ساختار نقطه ورود M15
struct M15_EntryPoint
{
   double      entryPrice;
   datetime    entryTime;
   bool        isConfirmed;
   double      rsiAtEntry;
   double      initialStopLoss;
   double      entryCandleLow;
   double      entryCandleHigh;
};

// ساختار موج الیوت
enum EWAVE_PHASE
{
   WAVE_UNKNOWN,
   WAVE_1_IMPULSE,
   WAVE_2_CORRECTION,
   WAVE_3_IMPULSE,
   WAVE_4_CORRECTION,
   WAVE_5_IMPULSE,
   WAVE_A_CORRECTION,
   WAVE_B_CORRECTION,
   WAVE_C_IMPULSE
};

struct ElliottWave
{
   EWAVE_PHASE currentPhase;
   double      waveStartPrice;
   datetime    waveStartTime;
   double      waveEndPrice;
   datetime    waveEndTime;
   double      waveLengthPips;
   bool        isValid;
   double      fibonacciRetracement;
   double      fibonacciExtensions[5];
};

//================ GLOBAL VARIABLES ================
TrendLine majorTrendlines[10];
int totalTrendlines = 0;
TradeSignal currentSignal;
M15_EntryPoint entryPoint;
ElliottWave currentElliottWave;

// اندیکاتورها
int atrHandle, rsiHandle, volumeHandle;
int rsiH1Handle, rsiM15Handle, atrH1Handle;
int zigzagHandle;

// مدیریت زمان
datetime lastH4BarTime = 0;
datetime lastH1BarTime = 0;
datetime lastM15BarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // بررسی جفت ارز و تایم‌فریم
   if(_Symbol != "EURUSD")
   {
      Alert("این EA فقط برای EURUSD بهینه شده است!");
      Print("نماد فعلی: ", _Symbol, " | مورد نیاز: EURUSD");
      return INIT_FAILED;
   }
   
   if(_Period != PERIOD_H4)
   {
      Alert("این EA فقط برای تایم‌فریم H4 بهینه شده است!");
      Print("تایم‌فریم فعلی: ", _Period, " | مورد نیاز: H4");
      return INIT_FAILED;
   }
   
   // ایجاد اندیکاتورها
   atrHandle = iATR(_Symbol, PERIOD_H4, 14);
   rsiHandle = iRSI(_Symbol, PERIOD_H4, RSI_Period, PRICE_CLOSE);
   volumeHandle = iVolumes(_Symbol, PERIOD_H4, VOLUME_TICK);
   
   if(atrHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
   {
      Alert("خطا در ایجاد اندیکاتورهای اصلی!");
      return INIT_FAILED;
   }
   
   if(UseH1_Confirmation)
   {
      rsiH1Handle = iRSI(_Symbol, PERIOD_H1, RSI_Period, PRICE_CLOSE);
      atrH1Handle = iATR(_Symbol, PERIOD_H1, 14);
   }
   
   if(UseM15_Entry)
   {
      rsiM15Handle = iRSI(_Symbol, PERIOD_M15, M15_RSI_Period, PRICE_CLOSE);
   }
   
   if(UseElliottWaveDetection)
   {
      zigzagHandle = iCustom(_Symbol, PERIOD_H4, "Examples\\ZigZag.ex5", 12, 5, 3);
   }
   
   // حذف اشیاء قدیمی
   if(DrawTrendlines)
   {
      ObjectsDeleteAll(0, "TL_");
      ObjectsDeleteAll(0, "EURUSD_");
   }
   
   // ریست کردن متغیرها
   currentSignal.isValid = false;
   entryPoint.isConfirmed = false;
   currentElliottWave.isValid = false;
   totalTrendlines = 0;
   
   // ریست آرایه‌های TP
   for(int i = 0; i < 4; i++)
   {
      currentSignal.tpHit[i] = false;
      currentSignal.tpPercentages[i] = 0;
   }
   
   // تنظیمات ترید
   trade.SetExpertMagicNumber(8888);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   Print("========================================");
   Print("EURUSD Complete Breakout System v8.2");
   Print("تایم‌فریم: H4 | نماد: EURUSD");
   Print("ویژگی‌ها: شکست خط روند + چند تایم‌فریم + الیوت + فیبوناچی");
   Print("استاپ: بر اساس دم کندل M15 | تریلینگ: هوشمند الیوت");
   Print("========================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع تشخیص سوینگ‌های قیمت                                       |
//+------------------------------------------------------------------+
bool FindSwingPoints(double &highs[], double &lows[], 
                     int &highBars[], int &lowBars[])
{
   int bars = SwingPointsLookback;
   double high[], low[];
   ArrayResize(high, bars);
   ArrayResize(low, bars);
   
   for(int i = 0; i < bars; i++)
   {
      high[i] = iHigh(_Symbol, PERIOD_H4, i);
      low[i] = iLow(_Symbol, PERIOD_H4, i);
   }
   
   // یافتن قله‌های ماژور
   int highCount = 0;
   for(int i = 5; i < bars - 5; i++)
   {
      bool isPeak = true;
      for(int j = 1; j <= 5; j++)
      {
         if(high[i] < high[i-j] || high[i] < high[i+j])
         {
            isPeak = false;
            break;
         }
      }
      if(isPeak)
      {
         ArrayResize(highs, highCount+1);
         ArrayResize(highBars, highCount+1);
         highs[highCount] = high[i];
         highBars[highCount] = i;
         highCount++;
      }
   }
   
   // یافتن دره‌های ماژور
   int lowCount = 0;
   for(int i = 5; i < bars - 5; i++)
   {
      bool isTrough = true;
      for(int j = 1; j <= 5; j++)
      {
         if(low[i] > low[i-j] || low[i] > low[i+j])
         {
            isTrough = false;
            break;
         }
      }
      if(isTrough)
      {
         ArrayResize(lows, lowCount+1);
         ArrayResize(lowBars, lowCount+1);
         lows[lowCount] = low[i];
         lowBars[lowCount] = i;
         lowCount++;
      }
   }
   
   Print(highCount, " قله و ", lowCount, " دره ماژور پیدا شد");
   return (highCount > 1 && lowCount > 1);
}

//+------------------------------------------------------------------+
//| محاسبه زاویه خط روند                                            |
//+------------------------------------------------------------------+
double CalculateTrendlineAngle(double price1, double price2, int bar1, int bar2)
{
   if(bar2 <= bar1) return 0;
   double priceDiff = price2 - price1;
   double barDiff = bar2 - bar1;
   double slope = priceDiff / barDiff;
   double angle = MathArctan(MathAbs(slope)) * 180 / M_PI;
   return angle;
}

//+------------------------------------------------------------------+
//| رسم خط روند روی چارت                                            |
//+------------------------------------------------------------------+
void DrawTrendLine(double price1, int bar1, double price2, int bar2, 
                   string name, color clr, int width = 2, bool ray = false)
{
   if(!DrawTrendlines) return;
   datetime time1 = iTime(_Symbol, PERIOD_H4, bar1);
   datetime time2 = iTime(_Symbol, PERIOD_H4, bar2);
   
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, ray);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   else
   {
      ObjectMove(0, name, 0, time1, price1);
      ObjectMove(0, name, 1, time2, price2);
   }
}

//+------------------------------------------------------------------+
//| تشخیص خطوط روند ماژور                                           |
//+------------------------------------------------------------------+
bool DetectMajorTrendlines()
{
   double highs[], lows[];
   int highBars[], lowBars[];
   
   if(!FindSwingPoints(highs, lows, highBars, lowBars))
   {
      Print("هیچ سوینگ ماژوری پیدا نشد");
      return false;
   }
   
   totalTrendlines = 0;
   
   // خط روند نزولی (اتصال قله‌ها)
   for(int i = 0; i < ArraySize(highs) - 1 && totalTrendlines < 10; i++)
   {
      for(int j = i + 1; j < ArraySize(highs) && totalTrendlines < 10; j++)
      {
         double angle = CalculateTrendlineAngle(highs[i], highs[j], highBars[i], highBars[j]);
         if(angle >= MinTrendlineAngle)
         {
            int touchCount = 1;
            double slope = (highs[j] - highs[i]) / (highBars[j] - highBars[i]);
            
            for(int k = 0; k < ArraySize(highs); k++)
            {
               if(k != i && k != j)
               {
                  double expectedPrice = highs[i] + slope * (highBars[k] - highBars[i]);
                  if(MathAbs(highs[k] - expectedPrice) <= 0.0010) touchCount++;
               }
            }
            
            if(touchCount >= 2)
            {
               majorTrendlines[totalTrendlines].startPrice = highs[i];
               majorTrendlines[totalTrendlines].endPrice = highs[j];
               majorTrendlines[totalTrendlines].startBar = highBars[i];
               majorTrendlines[totalTrendlines].endBar = highBars[j];
               majorTrendlines[totalTrendlines].isUpTrend = false;
               majorTrendlines[totalTrendlines].slope = slope;
               majorTrendlines[totalTrendlines].angle = angle;
               majorTrendlines[totalTrendlines].touchCount = touchCount;
               majorTrendlines[totalTrendlines].trendlineName = "TL_Down_" + IntegerToString(totalTrendlines);
               majorTrendlines[totalTrendlines].lastBreakTime = 0;
               
               if(DrawTrendlines)
               {
                  DrawTrendLine(highs[i], highBars[i], highs[j], highBars[j],
                               majorTrendlines[totalTrendlines].trendlineName,
                               EURUSD_DowntrendColor, 2, true);
               }
               totalTrendlines++;
            }
         }
      }
   }
   
   // خط روند صعودی (اتصال دره‌ها)
   for(int i = 0; i < ArraySize(lows) - 1 && totalTrendlines < 10; i++)
   {
      for(int j = i + 1; j < ArraySize(lows) && totalTrendlines < 10; j++)
      {
         double angle = CalculateTrendlineAngle(lows[i], lows[j], lowBars[i], lowBars[j]);
         if(angle >= MinTrendlineAngle)
         {
            int touchCount = 1;
            double slope = (lows[j] - lows[i]) / (lowBars[j] - lowBars[i]);
            
            for(int k = 0; k < ArraySize(lows); k++)
            {
               if(k != i && k != j)
               {
                  double expectedPrice = lows[i] + slope * (lowBars[k] - lowBars[i]);
                  if(MathAbs(lows[k] - expectedPrice) <= 0.0010) touchCount++;
               }
            }
            
            if(touchCount >= 2)
            {
               majorTrendlines[totalTrendlines].startPrice = lows[i];
               majorTrendlines[totalTrendlines].endPrice = lows[j];
               majorTrendlines[totalTrendlines].startBar = lowBars[i];
               majorTrendlines[totalTrendlines].endBar = lowBars[j];
               majorTrendlines[totalTrendlines].isUpTrend = true;
               majorTrendlines[totalTrendlines].slope = slope;
               majorTrendlines[totalTrendlines].angle = angle;
               majorTrendlines[totalTrendlines].touchCount = touchCount;
               majorTrendlines[totalTrendlines].trendlineName = "TL_Up_" + IntegerToString(totalTrendlines);
               majorTrendlines[totalTrendlines].lastBreakTime = 0;
               
               if(DrawTrendlines)
               {
                  DrawTrendLine(lows[i], lowBars[i], lows[j], lowBars[j],
                               majorTrendlines[totalTrendlines].trendlineName,
                               EURUSD_UptrendColor, 2, true);
               }
               totalTrendlines++;
            }
         }
      }
   }
   
   Print(totalTrendlines, " خط روند ماژور تشخیص داده شد");
   return (totalTrendlines > 0);
}

//+------------------------------------------------------------------+
//| بررسی واگرایی نزولی                                             |
//+------------------------------------------------------------------+
bool CheckBearishDivergence(int currentBar)
{
   int lookback = MathMin(RSI_Lookback, 30);
   double highs[];
   ArrayResize(highs, lookback);
   
   for(int i = 0; i < lookback; i++)
      highs[i] = iHigh(_Symbol, PERIOD_H4, currentBar + i);
   
   int peak1Index = ArrayMaximum(highs, 0, lookback/2);
   int peak2Index = ArrayMaximum(highs, lookback/2, lookback/2) + lookback/2;
   
   if(peak1Index < 0 || peak2Index < 0 || peak2Index <= peak1Index)
      return false;
   
   double peak1Price = highs[peak1Index];
   double peak2Price = highs[peak2Index];
   
   double rsiValues[];
   ArrayResize(rsiValues, lookback);
   if(CopyBuffer(rsiHandle, 0, currentBar, lookback, rsiValues) < lookback)
      return false;
   
   double peak1RSI = rsiValues[peak1Index];
   double peak2RSI = rsiValues[peak2Index];
   
   if(peak2Price > peak1Price && peak2RSI < peak1RSI)
   {
      Print("واگرایی نزولی تشخیص داده شد");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| بررسی واگرایی صعودی                                             |
//+------------------------------------------------------------------+
bool CheckBullishDivergence(int currentBar)
{
   int lookback = MathMin(RSI_Lookback, 30);
   double lows[];
   ArrayResize(lows, lookback);
   
   for(int i = 0; i < lookback; i++)
      lows[i] = iLow(_Symbol, PERIOD_H4, currentBar + i);
   
   int trough1Index = ArrayMinimum(lows, 0, lookback/2);
   int trough2Index = ArrayMinimum(lows, lookback/2, lookback/2) + lookback/2;
   
   if(trough1Index < 0 || trough2Index < 0 || trough2Index <= trough1Index)
      return false;
   
   double trough1Price = lows[trough1Index];
   double trough2Price = lows[trough2Index];
   
   double rsiValues[];
   ArrayResize(rsiValues, lookback);
   if(CopyBuffer(rsiHandle, 0, currentBar, lookback, rsiValues) < lookback)
      return false;
   
   double trough1RSI = rsiValues[trough1Index];
   double trough2RSI = rsiValues[trough2Index];
   
   if(trough2Price < trough1Price && trough2RSI > trough1RSI)
   {
      Print("واگرایی صعودی تشخیص داده شد");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| محاسبه میانگین حجم                                              |
//+------------------------------------------------------------------+
double GetAverageVolume(int period)
{
   double totalVolume = 0;
   for(int i = 1; i <= period; i++)
      totalVolume += iVolume(_Symbol, PERIOD_H4, i);
   return (period > 0) ? totalVolume / period : 0;
}

//+------------------------------------------------------------------+
//| بررسی شکست خط روند                                              |
//+------------------------------------------------------------------+
bool CheckTrendlineBreakout(TrendLine &tl, int currentBar)
{
   double currentPrice = iClose(_Symbol, PERIOD_H4, currentBar);
   double trendlineValue = tl.startPrice + (tl.slope * (currentBar - tl.startBar));
   
   double rsiArray[5];
   ArraySetAsSeries(rsiArray, true);
   if(CopyBuffer(rsiHandle, 0, 0, 5, rsiArray) < 5) return false;
   
   double rsiCurrent = rsiArray[0];
   double rsiPrev1 = rsiArray[1];
   
   double pointsPerPip = (_Digits == 5) ? 10.0 : 1.0;
   double breakoutDistancePoints = MathAbs(currentPrice - trendlineValue);
   double breakoutDistancePips = breakoutDistancePoints / _Point;
   if(_Digits == 5) breakoutDistancePips /= 10;
   
   double currentVolume = iVolume(_Symbol, PERIOD_H4, 0);
   double avgVolume = GetAverageVolume(20);
   
   // شکست خط روند صعودی (به پایین)
   if(tl.isUpTrend && currentPrice < trendlineValue)
   {
      if(breakoutDistancePips < BreakoutThreshold * 10000) return false;
      if(currentVolume < avgVolume * VolumeSpikeFactor) return false;
      if(!UseRSIConfirmation) return true;
      
      if(rsiCurrent < 50 && rsiCurrent < rsiPrev1) return true;
      if(rsiPrev1 > RSI_Overbought && rsiCurrent < RSI_Overbought) return true;
      if(CheckBearishDivergence(currentBar)) return true;
   }
   
   // شکست خط روند نزولی (به بالا)
   if(!tl.isUpTrend && currentPrice > trendlineValue)
   {
      if(breakoutDistancePips < BreakoutThreshold * 10000) return false;
      if(currentVolume < avgVolume * VolumeSpikeFactor) return false;
      if(!UseRSIConfirmation) return true;
      
      if(rsiCurrent > 50 && rsiCurrent > rsiPrev1) return true;
      if(rsiPrev1 < RSI_Oversold && rsiCurrent > RSI_Oversold) return true;
      if(CheckBullishDivergence(currentBar)) return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| تایید سیگنال در H1                                              |
//+------------------------------------------------------------------+
bool ConfirmH1Signal()
{
   if(!currentSignal.isValid) return false;
   
   double h1Price = iClose(_Symbol, PERIOD_H1, 0);
   double h1RSI[];
   ArrayResize(h1RSI, 3);
   ArraySetAsSeries(h1RSI, true);
   
   if(CopyBuffer(rsiH1Handle, 0, 0, 3, h1RSI) < 3) return false;
   
   if(!currentSignal.isBuy)
   {
      if(h1Price < currentSignal.h4_BreakPrice && h1RSI[0] < 50)
      {
         currentSignal.h1_ConfirmationPrice = h1Price;
         currentSignal.h1_ConfirmationTime = TimeCurrent();
         Print("تأیید H1 برای فروش: ", h1Price);
         return true;
      }
   }
   else
   {
      if(h1Price > currentSignal.h4_BreakPrice && h1RSI[0] > 50)
      {
         currentSignal.h1_ConfirmationPrice = h1Price;
         currentSignal.h1_ConfirmationTime = TimeCurrent();
         Print("تأیید H1 برای خرید: ", h1Price);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| پیدا کردن نقطه ورود M15 با استاپ بر اساس دم کندل               |
//+------------------------------------------------------------------+
bool FindM15EntryPoint()
{
   if(!currentSignal.isValid || 
      (UseH1_Confirmation && currentSignal.h1_ConfirmationPrice == 0))
      return false;
   
   if(TimeCurrent() - currentSignal.signalTime > MaxWaitForEntry * 3600)
   {
      Print("سیگنال منقضی شد");
      currentSignal.isValid = false;
      return false;
   }
   
   double m15Price = iClose(_Symbol, PERIOD_M15, 0);
   double m15RSI[];
   ArrayResize(m15RSI, 5);
   ArraySetAsSeries(m15RSI, true);
   
   if(CopyBuffer(rsiM15Handle, 0, 0, 5, m15RSI) < 5) return false;
   
   if(currentSignal.isBuy) // سیگنال خرید
   {
      int highIndex = iHighest(_Symbol, PERIOD_M15, MODE_HIGH, MaxPullbackBars, 1);
      int lowIndex = iLowest(_Symbol, PERIOD_M15, MODE_LOW, MaxPullbackBars, 1);
      
      double swingHigh = iHigh(_Symbol, PERIOD_M15, highIndex);
      double swingLow = iLow(_Symbol, PERIOD_M15, lowIndex);
      double pullbackLevel = swingHigh - ((swingHigh - swingLow) * PullbackDepth);
      
      if(m15Price <= pullbackLevel && m15RSI[0] >= M15_RSI_Entry && m15RSI[0] < 70)
      {
         entryPoint.entryPrice = m15Price;
         entryPoint.entryTime = TimeCurrent();
         entryPoint.rsiAtEntry = m15RSI[0];
         entryPoint.isConfirmed = true;
         
         // ========== محاسبه استاپ بر اساس دم پایین کندل ==========
         double entryCandleLow = iLow(_Symbol, PERIOD_M15, 0);
         double entryCandleHigh = iHigh(_Symbol, PERIOD_M15, 0);
         double candleRange = entryCandleHigh - entryCandleLow;
         double bufferFromWick = candleRange * (SL_BufferPercent / 100.0);
         
         if(UseCandleBasedSL)
         {
            // استاپ: 2 پیپ پایین‌تر از LOW کندل ورود
            entryPoint.initialStopLoss = entryCandleLow - (SL_WickOffset * _Point);
            if(_Digits == 5) entryPoint.initialStopLoss = entryCandleLow - (SL_WickOffset * 10 * _Point);
            
            // اضافه کردن بافر بر اساس ارتفاع کندل
            entryPoint.initialStopLoss -= bufferFromWick;
         }
         else
         {
            entryPoint.initialStopLoss = m15Price - (InitialSL_Pips * _Point);
            if(_Digits == 5) entryPoint.initialStopLoss = m15Price - (InitialSL_Pips * 10 * _Point);
         }
         
         // ذخیره اطلاعات کندل ورود
         entryPoint.entryCandleLow = entryCandleLow;
         entryPoint.entryCandleHigh = entryCandleHigh;
         currentSignal.entryCandleLow = entryCandleLow;
         currentSignal.entryCandleHigh = entryCandleHigh;
         currentSignal.entryCandleClose = m15Price;
         currentSignal.entryCandleTime = iTime(_Symbol, PERIOD_M15, 0);
         currentSignal.initialStopLoss = entryPoint.initialStopLoss;
         currentSignal.breakEvenActivated = false;
         currentSignal.currentWave = 1;
         
         Print("==========================================");
         Print("ورود خرید در M15");
         Print("قیمت ورود: ", m15Price);
         Print("دم پایین کندل: ", entryCandleLow);
         Print("استاپ اولیه: ", entryPoint.initialStopLoss);
         Print("فاصله استاپ: ", (m15Price - entryPoint.initialStopLoss) / _Point, " پیپ");
         Print("==========================================");
         return true;
      }
   }
   else // سیگنال فروش
   {
      int highIndex = iHighest(_Symbol, PERIOD_M15, MODE_HIGH, MaxPullbackBars, 1);
      int lowIndex = iLowest(_Symbol, PERIOD_M15, MODE_LOW, MaxPullbackBars, 1);
      
      double swingHigh = iHigh(_Symbol, PERIOD_M15, highIndex);
      double swingLow = iLow(_Symbol, PERIOD_M15, lowIndex);
      double pullbackLevel = swingLow + ((swingHigh - swingLow) * PullbackDepth);
      
      if(m15Price >= pullbackLevel && m15RSI[0] <= (100 - M15_RSI_Entry) && m15RSI[0] > 30)
      {
         entryPoint.entryPrice = m15Price;
         entryPoint.entryTime = TimeCurrent();
         entryPoint.rsiAtEntry = m15RSI[0];
         entryPoint.isConfirmed = true;
         
         // ========== محاسبه استاپ بر اساس دم بالای کندل ==========
         double entryCandleHigh = iHigh(_Symbol, PERIOD_M15, 0);
         double entryCandleLow = iLow(_Symbol, PERIOD_M15, 0);
         double candleRange = entryCandleHigh - entryCandleLow;
         double bufferFromWick = candleRange * (SL_BufferPercent / 100.0);
         
         if(UseCandleBasedSL)
         {
            // استاپ: 2 پیپ بالاتر از HIGH کندل ورود
            entryPoint.initialStopLoss = entryCandleHigh + (SL_WickOffset * _Point);
            if(_Digits == 5) entryPoint.initialStopLoss = entryCandleHigh + (SL_WickOffset * 10 * _Point);
            
            // اضافه کردن بافر بر اساس ارتفاع کندل
            entryPoint.initialStopLoss += bufferFromWick;
         }
         else
         {
            entryPoint.initialStopLoss = m15Price + (InitialSL_Pips * _Point);
            if(_Digits == 5) entryPoint.initialStopLoss = m15Price + (InitialSL_Pips * 10 * _Point);
         }
         
         // ذخیره اطلاعات کندل ورود
         entryPoint.entryCandleHigh = entryCandleHigh;
         entryPoint.entryCandleLow = entryCandleLow;
         currentSignal.entryCandleHigh = entryCandleHigh;
         currentSignal.entryCandleLow = entryCandleLow;
         currentSignal.entryCandleClose = m15Price;
         currentSignal.entryCandleTime = iTime(_Symbol, PERIOD_M15, 0);
         currentSignal.initialStopLoss = entryPoint.initialStopLoss;
         currentSignal.breakEvenActivated = false;
         currentSignal.currentWave = 1;
         
         Print("==========================================");
         Print("ورود فروش در M15");
         Print("قیمت ورود: ", m15Price);
         Print("دم بالای کندل: ", entryCandleHigh);
         Print("استاپ اولیه: ", entryPoint.initialStopLoss);
         Print("فاصله استاپ: ", (entryPoint.initialStopLoss - m15Price) / _Point, " پیپ");
         Print("==========================================");
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| محاسبه حجم معامله                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPips)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);
   
   double pipValue = 0.0001; // 1 پیپ برای EURUSD
   if(_Digits == 5) pipValue = 0.0001;
   
   double lot = riskAmount / (slPips * pipValue * 10);
   
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step > 0) lot = MathFloor(lot / step) * step;
   
   lot = MathMax(lot, MinLotSize);
   lot = MathMin(lot, MaxLotSize);
   
   return lot;
}

//+------------------------------------------------------------------+
//| دریافت ATR فعلی                                                 |
//+------------------------------------------------------------------+
double GetCurrentATR()
{
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) == 1)
      return atr[0];
   return 15 * _Point;
}

//+------------------------------------------------------------------+
//| محاسبه سطوح فیبوناچی                                            |
//+------------------------------------------------------------------+
void CalculateFibonacciLevels(TrendLine &tl)
{
   double waveLength = MathAbs(currentSignal.h4_BreakPrice - tl.startPrice);
   
   if(currentSignal.isBuy)
   {
      currentSignal.fibonacciLevels[1] = entryPoint.entryPrice + (waveLength * Fibo_TP1);
      currentSignal.fibonacciLevels[2] = entryPoint.entryPrice + (waveLength * Fibo_TP2);
      currentSignal.fibonacciLevels[3] = entryPoint.entryPrice + (waveLength * Fibo_TP3);
      currentSignal.fibonacciLevels[4] = entryPoint.entryPrice + (waveLength * Fibo_TP4);
      
      currentSignal.tpLevels[0] = currentSignal.fibonacciLevels[1];
      currentSignal.tpLevels[1] = currentSignal.fibonacciLevels[2];
      currentSignal.tpLevels[2] = currentSignal.fibonacciLevels[3];
      currentSignal.tpLevels[3] = currentSignal.fibonacciLevels[4];
   }
   else
   {
      currentSignal.fibonacciLevels[1] = entryPoint.entryPrice - (waveLength * Fibo_TP1);
      currentSignal.fibonacciLevels[2] = entryPoint.entryPrice - (waveLength * Fibo_TP2);
      currentSignal.fibonacciLevels[3] = entryPoint.entryPrice - (waveLength * Fibo_TP3);
      currentSignal.fibonacciLevels[4] = entryPoint.entryPrice - (waveLength * Fibo_TP4);
      
      currentSignal.tpLevels[0] = currentSignal.fibonacciLevels[1];
      currentSignal.tpLevels[1] = currentSignal.fibonacciLevels[2];
      currentSignal.tpLevels[2] = currentSignal.fibonacciLevels[3];
      currentSignal.tpLevels[3] = currentSignal.fibonacciLevels[4];
   }
   
   currentSignal.tpPercentages[0] = TP1_Percentage;
   currentSignal.tpPercentages[1] = TP2_Percentage;
   currentSignal.tpPercentages[2] = TP3_Percentage;
   currentSignal.tpPercentages[3] = TP4_Percentage;
   
   for(int i = 0; i < 4; i++) currentSignal.tpHit[i] = false;
   
   Print("سطوح فیبوناچی محاسبه شد:");
   for(int i = 1; i <= 4; i++)
      Print("TP", i, ": ", currentSignal.fibonacciLevels[i]);
}

//+------------------------------------------------------------------+
//| اجرای معامله با چندین TP                                        |
//+------------------------------------------------------------------+
void ExecuteMultiTPTrade()
{
   if(!entryPoint.isConfirmed || position.Select(_Symbol))
      return;
   
   double slPipsActual = MathAbs(entryPoint.entryPrice - entryPoint.initialStopLoss) / _Point;
   if(_Digits == 5) slPipsActual /= 10;
   
   double totalLot = CalculateLotSize(slPipsActual);
   double lotPerTP[4];
   
   for(int i = 0; i < 4; i++)
      lotPerTP[i] = totalLot * (currentSignal.tpPercentages[i] / 100.0);
   
   // باز کردن پوزیشن‌های جداگانه
   for(int i = 0; i < 4; i++)
   {
      if(lotPerTP[i] < MinLotSize) continue;
      
      string comment = StringFormat("%s TP%d - %.0f%% (SL: دم کندل)", 
                                   currentSignal.isBuy ? "Buy" : "Sell", 
                                   i+1, 
                                   currentSignal.tpPercentages[i]);
      
      if(currentSignal.isBuy)
      {
         trade.Buy(lotPerTP[i], _Symbol, entryPoint.entryPrice, 
                  entryPoint.initialStopLoss, currentSignal.tpLevels[i], comment);
      }
      else
      {
         trade.Sell(lotPerTP[i], _Symbol, entryPoint.entryPrice, 
                   entryPoint.initialStopLoss, currentSignal.tpLevels[i], comment);
      }
      
      if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         Print("TP", i+1, " باز شد - حجم: ", lotPerTP[i]);
      }
      Sleep(50);
   }
   
   entryPoint.isConfirmed = false;
   Print("معاملات با استاپ دم کندل اجرا شد");
}

//+------------------------------------------------------------------+
//| تشخیص امواج الیوت                                                |
//+------------------------------------------------------------------+
bool DetectElliottWaveH4()
{
   if(!UseElliottWaveDetection || zigzagHandle == INVALID_HANDLE)
      return false;
   
   double zigzagValues[50];
   ArraySetAsSeries(zigzagValues, true);
   if(CopyBuffer(zigzagHandle, 0, 0, 50, zigzagValues) < 20)
      return false;
   
   double wavePoints[];
   int waveIndices[];
   ArrayResize(wavePoints, 50);
   ArrayResize(waveIndices, 50);
   int waveCount = 0;
   
   for(int i = 0; i < 50 && waveCount < 20; i++)
   {
      if(zigzagValues[i] > 0)
      {
         wavePoints[waveCount] = zigzagValues[i];
         waveIndices[waveCount] = i;
         waveCount++;
      }
   }
   
   if(waveCount < 5) return false;
   
   // تشخیص الگوی 5 موجی صعودی
   if(wavePoints[0] < wavePoints[1] && 
      wavePoints[1] > wavePoints[2] &&
      wavePoints[2] < wavePoints[3] &&
      wavePoints[3] > wavePoints[4])
   {
      currentElliottWave.currentPhase = WAVE_5_IMPULSE;
      currentElliottWave.waveStartPrice = wavePoints[0];
      currentElliottWave.waveEndPrice = wavePoints[4];
      currentElliottWave.isValid = true;
      currentSignal.currentWave = 5;
      Print("موج الیوت 5 موجی صعودی تشخیص داده شد");
      return true;
   }
   
   // تشخیص الگوی 5 موجی نزولی
   if(wavePoints[0] > wavePoints[1] && 
      wavePoints[1] < wavePoints[2] &&
      wavePoints[2] > wavePoints[3] &&
      wavePoints[3] < wavePoints[4])
   {
      currentElliottWave.currentPhase = WAVE_5_IMPULSE;
      currentElliottWave.waveStartPrice = wavePoints[0];
      currentElliottWave.waveEndPrice = wavePoints[4];
      currentElliottWave.isValid = true;
      currentSignal.currentWave = 5;
      Print("موج الیوت 5 موجی نزولی تشخیص داده شد");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| تریلینگ استاپ هوشمند بر اساس الیوت و سود تضمین شده             |
//+------------------------------------------------------------------+
void ElliottWaveTrailingStop()
{
   if(!position.Select(_Symbol) || !UseWaveTrailing)
      return;
   
   double currentPrice = (position.PositionType() == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double entryPrice = position.PriceOpen();
   double currentSL = position.StopLoss();
   double currentTP = position.TakeProfit();
   double atrValue = GetCurrentATR();
   
   // محاسبه سود و ریسک به پیپ
   double profitPips = 0, riskPips = 0;
   
   if(position.PositionType() == POSITION_TYPE_BUY)
   {
      profitPips = (currentPrice - entryPrice) / _Point;
      riskPips = (entryPrice - entryPoint.initialStopLoss) / _Point;
   }
   else
   {
      profitPips = (entryPrice - currentPrice) / _Point;
      riskPips = (entryPoint.initialStopLoss - entryPrice) / _Point;
   }
   
   if(_Digits == 5)
   {
      profitPips /= 10;
      riskPips /= 10;
   }
   
   // ========== مرحله 1: بریک ایون (تضمین عدم ضرر) ==========
   if(!currentSignal.breakEvenActivated && profitPips >= (riskPips * BreakevenPercent / 100.0))
   {
      if(position.PositionType() == POSITION_TYPE_BUY)
      {
         if(trade.PositionModify(_Symbol, entryPrice, currentTP))
         {
            currentSignal.breakEvenActivated = true;
            Print("✓ بریک ایون فعال شد - استاپ به نقطه ورود منتقل شد");
            Print("  سود فعلی: ", profitPips, " پیپ | ریسک: ", riskPips, " پیپ");
         }
      }
      else
      {
         if(trade.PositionModify(_Symbol, entryPrice, currentTP))
         {
            currentSignal.breakEvenActivated = true;
            Print("✓ بریک ایون فعال شد - استاپ به نقطه ورود منتقل شد");
            Print("  سود فعلی: ", profitPips, " پیپ | ریسک: ", riskPips, " پیپ");
         }
      }
      currentSL = entryPrice;
   }
   
   // ========== مرحله 2: تشخیص موج 3 و فعالسازی تریلینگ ==========
   if(profitPips >= (riskPips * 1.5) && currentSignal.currentWave <= 2)
   {
      currentSignal.currentWave = 3;
      double newTrailingStop = 0;
      
      if(position.PositionType() == POSITION_TYPE_BUY)
      {
         newTrailingStop = currentPrice - (atrValue * (Wave3_TrailPercent / 100.0));
         if(newTrailingStop > entryPrice + (riskPips * 0.3 * _Point))
         {
            if(trade.PositionModify(_Symbol, newTrailingStop, currentTP))
            {
               Print("✓ موج 3 تشخیص داده شد - تریلینگ استاپ فعال");
               Print("  استاپ جدید: ", newTrailingStop, " | سود: ", profitPips, " پیپ");
            }
         }
      }
      else
      {
         newTrailingStop = currentPrice + (atrValue * (Wave3_TrailPercent / 100.0));
         if(newTrailingStop < entryPrice - (riskPips * 0.3 * _Point))
         {
            if(trade.PositionModify(_Symbol, newTrailingStop, currentTP))
            {
               Print("✓ موج 3 تشخیص داده شد - تریلینگ استاپ فعال");
               Print("  استاپ جدید: ", newTrailingStop, " | سود: ", profitPips, " پیپ");
            }
         }
      }
   }
   
   // ========== مرحله 3: تشخیص موج 5 و تقویت تریلینگ ==========
   if(profitPips >= (riskPips * 2.5) && currentSignal.currentWave <= 4)
   {
      currentSignal.currentWave = 5;
      double newTrailingStop = 0;
      
      if(position.PositionType() == POSITION_TYPE_BUY)
      {
         newTrailingStop = currentPrice - (atrValue * (Wave5_TrailPercent / 100.0));
         if(newTrailingStop > entryPrice + (riskPips * 0.5 * _Point))
         {
            if(trade.PositionModify(_Symbol, newTrailingStop, currentTP))
            {
               Print("✓ موج 5 تشخیص داده شد - تریلینگ استاپ تقویت شد");
               Print("  استاپ جدید: ", newTrailingStop, " | سود: ", profitPips, " پیپ");
            }
         }
      }
      else
      {
         newTrailingStop = currentPrice + (atrValue * (Wave5_TrailPercent / 100.0));
         if(newTrailingStop < entryPrice - (riskPips * 0.5 * _Point))
         {
            if(trade.PositionModify(_Symbol, newTrailingStop, currentTP))
            {
               Print("✓ موج 5 تشخیص داده شد - تریلینگ استاپ تقویت شد");
               Print("  استاپ جدید: ", newTrailingStop, " | سود: ", profitPips, " پیپ");
            }
         }
      }
   }
   
   // ========== مرحله 4: تریلینگ تدریجی برای محافظت از سود ==========
   if(profitPips > riskPips && currentSignal.currentWave >= 3)
   {
      double optimalTrail = 0;
      
      if(position.PositionType() == POSITION_TYPE_BUY)
      {
         optimalTrail = currentPrice - (profitPips * 0.4 * _Point);
         if(_Digits == 5) optimalTrail = currentPrice - (profitPips * 4 * _Point);
         
         if(optimalTrail > currentSL + (10 * _Point))
         {
            trade.PositionModify(_Symbol, optimalTrail, currentTP);
            Print("تریلینگ تدریجی: استاپ به ", optimalTrail, " منتقل شد");
         }
      }
      else
      {
         optimalTrail = currentPrice + (profitPips * 0.4 * _Point);
         if(_Digits == 5) optimalTrail = currentPrice + (profitPips * 4 * _Point);
         
         if(optimalTrail < currentSL - (10 * _Point))
         {
            trade.PositionModify(_Symbol, optimalTrail, currentTP);
            Print("تریلینگ تدریجی: استاپ به ", optimalTrail, " منتقل شد");
         }
      }
   }
   
   currentSignal.trailingStop = currentSL;
}

//+------------------------------------------------------------------+
//| تابع اصلی OnTick                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   if(IsStopped()) return;
   
   datetime currentH4BarTime = iTime(_Symbol, PERIOD_H4, 0);
   datetime currentH1BarTime = iTime(_Symbol, PERIOD_H1, 0);
   datetime currentM15BarTime = iTime(_Symbol, PERIOD_M15, 0);
   
   // ========== مرحله 1: تشخیص خطوط روند در H4 ==========
   if(currentH4BarTime != lastH4BarTime)
   {
      lastH4BarTime = currentH4BarTime;
      Print("=== بررسی خطوط روند H4 ===");
      
      if(DetectMajorTrendlines())
      {
         for(int i = 0; i < totalTrendlines; i++)
         {
            majorTrendlines[i].currentValue = majorTrendlines[i].startPrice + 
                                            (majorTrendlines[i].slope * (0 - majorTrendlines[i].startBar));
            
            if(TimeCurrent() - majorTrendlines[i].lastBreakTime < 86400) continue;
            
            if(CheckTrendlineBreakout(majorTrendlines[i], 0))
            {
               Print("!!! شکست خط روند شناسایی شد !!!");
               
               currentSignal.isValid = true;
               currentSignal.isBuy = !majorTrendlines[i].isUpTrend;
               currentSignal.h4_BreakPrice = iClose(_Symbol, PERIOD_H4, 0);
               currentSignal.signalTime = TimeCurrent();
               currentSignal.currentWave = 1;
               currentSignal.waveStartPrice = currentSignal.h4_BreakPrice;
               currentSignal.h1_ConfirmationPrice = 0;
               currentSignal.breakEvenActivated = false;
               
               majorTrendlines[i].lastBreakTime = TimeCurrent();
               entryPoint.isConfirmed = false;
               
               if(UseElliottWaveDetection) DetectElliottWaveH4();
               
               if(EnableAlerts)
               {
                  string alertMsg = StringFormat("شکست %s در EURUSD H4\nقیمت: %.5f",
                                                currentSignal.isBuy ? "صعودی" : "نزولی",
                                                currentSignal.h4_BreakPrice);
                  Alert(alertMsg);
               }
               break;
            }
         }
      }
   }
   
   // ========== مرحله 2: تأیید H1 ==========
   if(currentSignal.isValid && currentH1BarTime != lastH1BarTime)
   {
      lastH1BarTime = currentH1BarTime;
      if(UseH1_Confirmation)
      {
         if(ConfirmH1Signal())
            Print("سیگنال در H1 تأیید شد");
         else if(TimeCurrent() - currentSignal.signalTime > MaxWaitForEntry * 3600)
         {
            currentSignal.isValid = false;
            Print("تأیید H1 دریافت نشد - سیگنال باطل شد");
         }
      }
   }
   
   // ========== مرحله 3: نقطه ورود M15 ==========
   if(currentSignal.isValid && 
      (!UseH1_Confirmation || currentSignal.h1_ConfirmationPrice > 0))
   {
      if(currentM15BarTime != lastM15BarTime)
      {
         lastM15BarTime = currentM15BarTime;
         
         if(UseM15_Entry && !entryPoint.isConfirmed)
         {
            if(FindM15EntryPoint())
            {
               if(totalTrendlines > 0)
                  CalculateFibonacciLevels(majorTrendlines[0]);
            }
         }
         
         if(entryPoint.isConfirmed && !position.Select(_Symbol))
            ExecuteMultiTPTrade();
      }
   }
   
   // ========== مرحله 4: مدیریت پوزیشن‌های باز ==========
   if(position.Select(_Symbol))
      ElliottWaveTrailingStop();
   
   // ========== مرحله 5: نمایش وضعیت ==========
   DisplayStatus();
}

//+------------------------------------------------------------------+
//| نمایش وضعیت سیستم                                               |
//+------------------------------------------------------------------+
void DisplayStatus()
{
   string status = "EURUSD Complete Breakout System v8.2\n";
   status += "========================================\n";
   status += StringFormat("خطوط روند: %d | زمان: %s\n", 
                        totalTrendlines, 
                        TimeToString(TimeCurrent(), TIME_MINUTES));
   status += "----------------------------------------\n";
   
   if(currentSignal.isValid)
   {
      status += StringFormat("سیگنال: %s | قیمت: %.5f\n",
                           currentSignal.isBuy ? "خرید" : "فروش",
                           currentSignal.h4_BreakPrice);
      status += StringFormat("زمان سیگنال: %s\n",
                           TimeToString(currentSignal.signalTime, TIME_MINUTES));
      
      if(UseH1_Confirmation)
         status += StringFormat("تأیید H1: %s\n",
                              currentSignal.h1_ConfirmationPrice > 0 ? "✓" : "⏳");
      
      status += StringFormat("ورود M15: %s\n",
                           entryPoint.isConfirmed ? "✓" : "⏳");
      
      if(entryPoint.isConfirmed)
      {
         status += StringFormat("استاپ اولیه: %.5f (دم کندل)\n", 
                              entryPoint.initialStopLoss);
      }
      
      if(UseElliottWaveDetection && currentElliottWave.isValid)
         status += StringFormat("الیوت: موج %d\n", currentSignal.currentWave);
   }
   else
      status += "در انتظار سیگنال شکست...\n";
   
   status += "----------------------------------------\n";
   
   if(position.Select(_Symbol))
   {
      double profitPips = 0;
      if(position.PositionType() == POSITION_TYPE_BUY)
         profitPips = (position.PriceCurrent() - position.PriceOpen()) / _Point;
      else
         profitPips = (position.PriceOpen() - position.PriceCurrent()) / _Point;
      
      if(_Digits == 5) profitPips /= 10;
      
      status += StringFormat("پوزیشن: %s | حجم: %.2f\n",
                           position.PositionType() == POSITION_TYPE_BUY ? "خرید" : "فروش",
                           position.Volume());
      status += StringFormat("ورود: %.5f | جاری: %.5f\n",
                           position.PriceOpen(),
                           position.PriceCurrent());
      status += StringFormat("سود: %.2f $ | %.1f پیپ\n",
                           position.Profit(), profitPips);
      status += StringFormat("استاپ: %.5f %s\n",
                           position.StopLoss(),
                           currentSignal.breakEvenActivated ? "(بریک ایون)" : "");
   }
   else
      status += "پوزیشن باز: ندارد\n";
   
   status += "========================================";
   Comment(status);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(DrawTrendlines)
      ObjectsDeleteAll(0, "TL_");
   
   IndicatorRelease(atrHandle);
   IndicatorRelease(rsiHandle);
   IndicatorRelease(volumeHandle);
   if(rsiH1Handle != INVALID_HANDLE) IndicatorRelease(rsiH1Handle);
   if(rsiM15Handle != INVALID_HANDLE) IndicatorRelease(rsiM15Handle);
   if(zigzagHandle != INVALID_HANDLE) IndicatorRelease(zigzagHandle);
   
   Comment("");
   Print("EA متوقف شد - دلیل: ", reason);
}
//+------------------------------------------------------------------+