//+------------------------------------------------------------------+
//| ساختارهای داده مشترک بین تمام کلاس‌ها
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

//+------------------------------------------------------------------+
//| ساختار خط روند
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| وضعیت امواج الیوت
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| ساختار موج الیوت
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| ساختار سیگنال تجاری
//+------------------------------------------------------------------+
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
   double      entryCandleLow;
   double      entryCandleHigh;
   double      entryCandleClose;
   datetime    entryCandleTime;
   double      initialStopLoss;
   bool        breakEvenActivated;
   int         brokenTrendlineIndex;
};

//+------------------------------------------------------------------+
//| ساختار نقطه ورود M15
//+------------------------------------------------------------------+
struct M15_EntryPoint
{
   double      entryPrice;
   datetime    entryTime;
   bool        isConfirmed;
   double      rsiAtEntry;
   double      initialStopLoss;
   double      entryCandleLow;
   double      entryCandleHigh;
   double      entryZoneTop;
   double      entryZoneBottom;
};