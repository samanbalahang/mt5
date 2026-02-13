//+------------------------------------------------------------------+
//| ElliottWaveRobot2.mq5                                           |
//| EURUSD Complete Breakout System v8.3                            |
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version   "8.3"
#property strict
#property description "H4 Trendline Breakout + Multi-Timeframe + Elliott Wave + Fibonacci"
#property description "استاپ بر اساس آخرین کندل زیر خط روند H4"
#property description "تریل فیبوناچی در H1 + تشخیص نویز با MACD/RSI/الیوت"

//===================================================================
// >>>>>>>>>>     شامل کردن تمام کلاس‌ها     <<<<<<<<<<
//===================================================================
#include "../Include/ElliottWaveRobot/Structures.mqh"
#include "../Include/ElliottWaveRobot/IndicatorManager.mqh"
#include "../Include/ElliottWaveRobot/TrendLineDetector.mqh"
#include "../Include/ElliottWaveRobot/ElliottWaveAnalyzer.mqh"
#include "../Include/ElliottWaveRobot/FibonacciManager.mqh"
#include "../Include/ElliottWaveRobot/RiskManager.mqh"
#include "../Include/ElliottWaveRobot/TradeExecutor.mqh"
#include "../Include/ElliottWaveRobot/M15EntryManager.mqh"
#include "../Include/ElliottWaveRobot/TrailingStopManager.mqh"
#include "../Include/ElliottWaveRobot/VisualDisplay.mqh"

//===================================================================
// >>>>>>>>>>     ورودی‌های ربات (INPUT)     <<<<<<<<<<
//===================================================================

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
input double   EntryZoneWidth = 5.0;         // عرض ناحیه ورود (پیپ)

// بخش 4: تنظیمات فیبوناچی
input string   SECTION4 = "=== FIBONACCI SETTINGS ===";
input bool     UseMultipleTPs = true;        // استفاده از چندین TP
input double   Fibo_TP1 = 0.236;             // TP اول (23.6%)
input double   Fibo_TP2 = 0.382;             // TP دوم (38.2%)
input double   Fibo_TP3 = 0.618;             // TP سوم (61.8%)
input double   Fibo_TP4 = 1.0;               // TP چهارم (100%)
input double   TP1_Percentage = 30;          // درصد حجم برای TP1
input double