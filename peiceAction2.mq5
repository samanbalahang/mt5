//+------------------------------------------------------------------+
//|                                                     priceAction.mq5 |
//|                                     Albrooks Style System EA    |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "3.11"  // نسخه به‌روز شده با پشتیبانی از روش آلفونسو
#property description "ربات تریدر بر اساس روش البروکس - نسخه نهایی"
#property description "تشخیص اسپایک، کانال، رنج، پینبار، انگالف، فلگ، مثلث، ودج"
#property description "EMA20/50 - واگرایی RSI - الگوهای هارمونیک - مدیریت ریسک پیشرفته"
#property description "بهینه شده برای بروکرهای 4 و 5 رقمی - گزارش تاریخچه معاملات"
#property description "تشخیص باز و بسته بودن بازار - توقف پس از 3 ضرر روزانه"
#property description "مدیریت هوشمند روزهای معاملاتی با شیء TradeAbleDay"
#property description "SL اجباری 6 پیپ در صورت عدم ثبت SL در معامله قبلی"
#property description "اضافه شدن روش آلفونسو (عرضه و تقاضا) - قابل فعال/غیرفعال‌سازی"
#property strict

//+------------------------------------------------------------------+
//| شامل کردن تمام کامپوننت‌ها                                         |
//+------------------------------------------------------------------+
#include "../Include/priceAction2/MarketSessionManager.mqh"
#include "../Include/priceAction2/CandleTypeDetector.mqh"
#include "../Include/priceAction2/TrendChannelDetector.mqh"
#include "../Include/priceAction2/SupportResistanceManager.mqh"
#include "../Include/priceAction2/EntrySignalManager.mqh"
#include "../Include/priceAction2/TrendCycleManager.mqh"
#include "../Include/priceAction2/TradeRiskManager.mqh"
#include "../Include/priceAction2/MovingAverageManager.mqh"
#include "../Include/priceAction2/RSIManager.mqh"
#include "../Include/priceAction2/PatternDetector.mqh"
#include "../Include/priceAction2/DayTradeManager.mqh"       // کلاس CDayTradeManager
#include "../Include/priceAction2/TradeHistoryArray.mqh"    // کلاس CTradeHistoryArray
#include "../Include/priceAction2/AlfonsoSupplyDemand.mqh"  // کامپوننت آلفونسو

//+------------------------------------------------------------------+
//| پارامترهای ورودی                                                 |
//+------------------------------------------------------------------+
// --- تنظیمات عمومی ---
sinput group "========== تنظیمات عمومی =========="
sinput bool     InpEnableTrading = true;           // فعال بودن ربات
sinput int      InpMagicNumber = 202502;           // مجیک نامبر
sinput string   InpTradeComment = "AlbrooksBot";   // کامنت معاملات
sinput bool     InpSaveHistory = true;            // ذخیره تاریخچه معاملات
sinput bool     InpShowDailyReport = true;        // نمایش گزارش روزانه
sinput bool     InpShowJSONOutput = false;        // نمایش خروجی JSON

// --- تنظیمات بازار ---
sinput group "========== تنظیمات بازار =========="
sinput bool     InpCheckMarketHours = true;       // بررسی ساعات معاملاتی
sinput bool     InpTradeOnlyOpenMarket = true;    // معامله فقط در بازار باز
sinput bool     InpShowMarketStatus = true;       // نمایش وضعیت بازار

// --- تنظیمات ریسک و توقف معاملات ---
sinput group "========== مدیریت ریسک و توقف =========="
sinput int      InpMaxDailyLoss = 3;              // حداکثر ضرر روزانه (تعداد معامله)
sinput bool     InpStopAfterMaxLoss = true;       // توقف پس از حداکثر ضرر
sinput int      InpForcedSLPips = 6;              // فاصله SL اجباری (پیپ)
sinput bool     InpUseForcedSLAfterFailure = true; // استفاده از SL اجباری پس از شکست

// --- تنظیمات تایم فریم ---
sinput group "========== تایم فریم‌ها =========="
sinput ENUM_TIMEFRAMES InpMainTimeframe = PERIOD_H1;     // تایم فریم اصلی
sinput ENUM_TIMEFRAMES InpHigherTimeframe = PERIOD_H4;   // تایم فریم بالاتر
sinput ENUM_TIMEFRAMES InpEntryTimeframe = PERIOD_M5;    // تایم فریم ورود

// --- تنظیمات ریسک پایه ---
sinput group "========== مدیریت ریسک =========="
sinput double   InpRiskPerTrade = 1.0;             // ریسک هر معامله (درصد)
sinput double   InpRiskPerDay = 3.0;              // ریسک روزانه (درصد)
sinput double   InpMinRiskReward = 1.5;           // حداقل ریسک به ریوارد
sinput double   InpMaxSpread = 2.0;              // حداکثر اسپرد (پیپ)
sinput int      InpMaxPositions = 3;             // حداکثر پوزیشن همزمان

// --- تنظیمات نحوه ورود به معامله ---
sinput group "========== نحوه ورود به معامله =========="
sinput bool     InpUseFullCapital = false;        // استفاده از کل سرمایه

// --- تنظیمات روش آلفونسو (عرضه و تقاضا) ---
sinput group "========== روش آلفونسو (عرضه و تقاضا) =========="
sinput bool     InpUseAlfonso = false;             // فعال‌سازی روش آلفونسو
sinput int      InpAlfonsoDaysToKeep = 30;         // مدت نگهداری سطوح (روز)

// --- تنظیمات حد ضرر و سود ---
sinput group "========== حد ضرر و سود =========="
sinput bool     InpUseTrailingStop = true;        // استفاده از تریلینگ استاپ
sinput double   InpTrailingActivation = 1.0;      // فعالسازی تریلینگ (درصد)
sinput double   InpTrailingDistance = 0.5;        // فاصله تریلینگ (درصد)
sinput bool     InpUseBreakeven = true;           // انتقال به بریک ایون
sinput double   InpBreakevenActivation = 1.0;     // فعالسازی بریک ایون (درصد)

// --- تنظیمات میانگین متحرک ---
sinput group "========== میانگین متحرک =========="
sinput bool     InpUseEMA = true;                 // استفاده از EMA
sinput int      InpEMAFast = 20;                 // EMA سریع
sinput int      InpEMASlow = 50;                 // EMA کند
sinput bool     InpUseEMAAsTarget = true;        // استفاده از EMA به عنوان حد سود
sinput bool     InpTwoHourRule = true;           // قانون 2 ساعت

// --- تنظیمات RSI و واگرایی ---
sinput group "========== RSI و واگرایی =========="
sinput bool     InpUseRSI = true;                // استفاده از RSI
sinput int      InpRSIPeriod = 14;              // دوره RSI
sinput double   InpOverbought = 70;             // سطح اشباع خرید
sinput double   InpOversold = 30;               // سطح اشباع فروش
sinput bool     InpUseDivergence = true;        // استفاده از واگرایی

// --- تنظیمات الگوها ---
sinput group "========== الگوهای کلاسیک =========="
sinput bool     InpUseFlag = true;              // استفاده از الگوی فلگ
sinput bool     InpUseTriangle = true;          // استفاده از الگوی مثلث
sinput bool     InpUseHeadShoulders = true;     // استفاده از هد اند شولدر
sinput bool     InpUseBarbedWire = true;        // استفاده از سیم خاردار
sinput bool     InpUseRectangle = true;         // استفاده از مستطیل

// --- تنظیمات سیگنال ---
sinput group "========== تنظیمات سیگنال =========="
sinput bool     InpUsePinBar = true;              // استفاده از پین بار
sinput bool     InpUseEngulfing = true;           // استفاده از انگالف
sinput bool     InpUseDoubleTopBottom = true;     // استفاده از سقف/کف دوقلو
sinput bool     InpUseBreakoutPullback = true;    // استفاده از بریک‌اوت + پولبک
sinput int      InpMinSignalStrength = 3;         // حداقل قدرت سیگنال

// --- تنظیمات فیلتر روند ---
sinput group "========== فیلتر روند =========="
sinput bool     InpTradeWithHigherTrend = true;   // معامله همجهت با تایم بالاتر
sinput bool     InpAvoidCounterTrend = true;      // اجتناب از معاملات خلاف روند
sinput bool     InpUseSpikeFilter = true;         // عدم معامله خلاف اسپایک

// --- تنظیمات پیشرفته ---
sinput group "========== تنظیمات پیشرفته =========="
sinput int      InpSwingStrength = 2;             // قدرت سقف/کف
sinput int      InpMinSpikeCandles = 4;           // حداقل کندل برای اسپایک
sinput double   InpTouchTolerance = 0.0001;       // تلورانس برخورد
sinput double   InpOverlapThreshold = 0.7;        // آستانه همپوشانی

//+------------------------------------------------------------------+
//| کلاس اصلی ربات                                                  |
//+------------------------------------------------------------------+
class CAlbrooksStyleBot
{
private:
   // کامپوننت‌های اصلی
   CandleTypeDetector        candleDetector;
   TrendChannelDetector      trendDetector;
   SupportResistanceManager  srManager;
   EntrySignalManager        entryManager;
   TrendCycleManager         cycleManager;
   TradeRiskManager          riskManager;
   MovingAverageManager      maManager;
   RSIManager               rsiManager;
   PatternDetector          patternDetector;
   CMarketSessionManager    sessionManager;
   CAlfonsoSupplyDemand      alfonso;               // کامپوننت آلفونسو
   
   // آرایه تاریخچه معاملات
   CTradeHistoryArray       historyArray;
   
   // مدیر روزهای معاملاتی (شیء TradeAbleDay)
   CDayTradeManager         dayManager;
   
   // آرایه‌های قیمت
   MqlRates                  mainRates[];
   MqlRates                  higherRates[];
   MqlRates                  entryRates[];
   
   // متغیرهای داخلی
   datetime                  lastBarTime;
   bool                      isInitialized;
   int                       totalSignals;
   int                       totalTrades;
   int                       brokerDigits;
   double                    pointValue;
   double                    pipValue;
   double                    tickValue;
   double                    tickSize;
   int                       lastReportDay;
   datetime                  lastMarketWarningTime;
   
   // نگاشت تیکت به tradeId
   struct TicketMap
   {
      ulong           ticket;
      int             tradeId;
   };
   TicketMap                ticketToTradeId[100];
   int                      ticketMapCount;
   
public:
   CAlbrooksStyleBot()
   {
      isInitialized = false;
      lastBarTime = 0;
      totalSignals = 0;
      totalTrades = 0;
      lastReportDay = 0;
      lastMarketWarningTime = 0;
      ticketMapCount = 0;
      
      InitializeBrokerSettings();
   }
   
   ~CAlbrooksStyleBot()
   {
      if(InpSaveHistory)
      {
         MqlDateTime dt;
         TimeToCurrent(dt);
         string filename = StringFormat("TradeHistory_%04d%02d%02d_Final.dat", dt.year, dt.mon, dt.day);
         historyArray.SaveToFile(filename);
         dayManager.SaveToFile("DayStatus.dat");
         
         if(InpShowJSONOutput)
         {
            historyArray.PrintAllTradesAsJSON();
            dayManager.PrintAllDaysAsJSON();
         }
      }
   }
   
   void InitializeBrokerSettings()
   {
      brokerDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(brokerDigits == 5 || brokerDigits == 3)
         pipValue = pointValue * 10;
      else if(brokerDigits == 4 || brokerDigits == 2)
         pipValue = pointValue;
      else
         pipValue = pointValue;
      
      tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      Print("🔄 تنظیمات بروکر:");
      Print("   - نماد: ", _Symbol);
      Print("   - رقم اعشار: ", brokerDigits);
      Print("   - Point: ", pointValue);
      Print("   - Pip Value: ", pipValue);
      Print("   - Tick Value: ", tickValue);
   }
   
   double PipsToPrice(double pips) { return pips * pipValue; }
   double PriceToPips(double price) { return price / pipValue; }
   
   void MapTicketToTradeId(ulong ticket, int tradeId)
   {
      if(ticketMapCount < 100)
      {
         ticketToTradeId[ticketMapCount].ticket = ticket;
         ticketToTradeId[ticketMapCount].tradeId = tradeId;
         ticketMapCount++;
      }
   }
   
   int GetTradeIdFromTicket(ulong ticket)
   {
      for(int i = 0; i < ticketMapCount; i++)
         if(ticketToTradeId[i].ticket == ticket)
            return ticketToTradeId[i].tradeId;
      return 0;
   }
   
   bool IsMarketOpenForTrading()
   {
      if(!InpCheckMarketHours || !InpTradeOnlyOpenMarket)
         return true;
      
      bool isOpen = sessionManager.IsMarketOpen();
      
      if(!isOpen && InpShowMarketStatus)
      {
         if(TimeCurrent() - lastMarketWarningTime > 3600)
         {
            Print("⏰ ", sessionManager.GetMarketStatusText());
            lastMarketWarningTime = TimeCurrent();
         }
      }
      
      return isOpen;
   }
   
   bool Initialize()
   {
      Print("══════════════════════════════════════════════");
      Print("🤖 راه‌اندازی ربات البروکس استایل نسخه 3.11");
      Print("══════════════════════════════════════════════");
      
      sessionManager.SetSymbol(_Symbol);
      
      if(InpShowMarketStatus)
         Print(sessionManager.GetMarketStatusText());
      
      if(InpSaveHistory)
      {
         historyArray.LoadFromFile("TradeHistory_Auto.dat");
         dayManager.LoadFromFile("DayStatus.dat");
      }
      
      riskManager.SetFullCapitalMode(InpUseFullCapital);
      riskManager.SetForcedSLDistance(InpForcedSLPips);
      
      if(InpUseEMA)
      {
         if(!maManager.InitializeEMA())
            Print("⚠️ اخطار: EMA راه‌اندازی نشد");
         else
            Print("✅ EMA20/50 با موفقیت راه‌اندازی شد");
      }
      
      if(InpUseRSI)
      {
         if(!rsiManager.InitializeRSI())
            Print("⚠️ اخطار: RSI راه‌اندازی نشد");
         else
            Print("✅ RSI با موفقیت راه‌اندازی شد");
      }
      
      dayManager.ResetForNewDay();
      isInitialized = true;
      
      Print("══════════════════════════════════════════════");
      Print("✅ ربات با موفقیت راه‌اندازی شد");
      Print("💰 نحوه ورود: ", InpUseFullCapital ? "کل سرمایه (یکجا)" : "الگوی 20/80");
      Print("📊 EMA: ", InpUseEMA ? "فعال" : "غیرفعال");
      Print("📈 RSI: ", InpUseRSI ? "فعال" : "غیرفعال");
      Print("🔄 بروکر: ", brokerDigits, " رقم اعشار");
      Print("⏰ بررسی بازار: ", InpCheckMarketHours ? "فعال" : "غیرفعال");
      Print("🚫 توقف پس از ", InpMaxDailyLoss, " ضرر: ", InpStopAfterMaxLoss ? "فعال" : "غیرفعال");
      Print("🔒 SL اجباری: ", InpForcedSLPips, " پیپ - ", InpUseForcedSLAfterFailure ? "فعال" : "غیرفعال");
      Print("📊 روش آلفونسو: ", InpUseAlfonso ? "فعال" : "غیرفعال");
      
      TradeAbleDay* today = dayManager.GetCurrentDay();
      if(today != NULL && !today.tradeable)
         Print("⚠️ وضعیت: امروز معاملات متوقف شده است");
      
      Print("══════════════════════════════════════════════");
      
      return true;
   }
   
   bool RefreshRates()
   {
      if(CopyRates(_Symbol, InpMainTimeframe, 0, 100, mainRates) < 50) return false;
      if(CopyRates(_Symbol, InpHigherTimeframe, 0, 50, higherRates) < 20) return false;
      if(CopyRates(_Symbol, InpEntryTimeframe, 0, 200, entryRates) < 100) return false;
      
      if(InpUseEMA) maManager.RefreshEMA();
      if(InpUseRSI) rsiManager.RefreshRSI();
      
      return true;
   }
   
   void ShowDailyReport()
   {
      if(!InpShowDailyReport) return;
      
      MqlDateTime dt;
      TimeToCurrent(dt);
      int todayKey = dt.year * 10000 + dt.mon * 100 + dt.day;
      
      if(lastReportDay != todayKey)
      {
         Print(dayManager.GetTodayStats());
         lastReportDay = todayKey;
      }
   }
   
   ENUM_TREND_DIRECTION AnalyzeHigherTimeframeTrend()
   {
      if(ArraySize(higherRates) < 20) return TREND_UNDEFINED;
      return trendDetector.DetectTrend(higherRates, ArraySize(higherRates) - 20, 20);
   }
   
   bool IsAlignedWithHigherTimeframe(ENUM_TREND_DIRECTION entryDirection)
   {
      if(!InpTradeWithHigherTrend) return true;
      ENUM_TREND_DIRECTION higherTrend = AnalyzeHigherTimeframeTrend();
      if(higherTrend == TREND_UNDEFINED || higherTrend == TREND_SIDEWAYS) return true;
      return (entryDirection == higherTrend);
   }
   
   CycleInfo GetCurrentMainCycle()
   {
      if(ArraySize(mainRates) < 30)
      {
         CycleInfo empty;
         empty.isValid = false;
         return empty;
      }
      return cycleManager.GetCurrentCycle(mainRates, ArraySize(mainRates) - 1, 30);
   }
   
   void CheckPatterns()
   {
      if(ArraySize(mainRates) < 50) return;
      int mainIdx = ArraySize(mainRates) - 1;
      
      if(InpUseFlag)
      {
         ENUM_TREND_DIRECTION trend = trendDetector.DetectTrend(mainRates, mainIdx - 30, 20);
         PatternInfo flag = patternDetector.DetectFlag(mainRates, mainIdx, trend);
         if(flag.isValid) Print("🚩 الگوی فلگ شناسایی شد");
      }
      if(InpUseTriangle)
      {
         PatternInfo triangle = patternDetector.DetectTriangle(mainRates, mainIdx - 30, mainIdx);
         if(triangle.isValid) Print("🔺 الگوی مثلث شناسایی شد");
      }
   }
   
   void CheckRSIDivergence()
   {
      if(!InpUseRSI || !InpUseDivergence) return;
      if(ArraySize(entryRates) < 50) return;
      
      if(rsiManager.IsOverbought()) Print("⚠️ هشدار: اشباع خرید");
      if(rsiManager.IsOversold()) Print("⚠️ هشدار: اشباع فروش");
   }
   
   SignalBar FindEntrySignal()
   {
      SignalBar bestSignal;
      bestSignal.type = SIGNAL_NONE;
      
      if(ArraySize(entryRates) < 20) return bestSignal;
      
      int currentIdx = ArraySize(entryRates) - 2;
      ENUM_TREND_DIRECTION entryTrend = trendDetector.DetectTrend(entryRates, currentIdx - 20, 20);
      
      SignalBar signals[20];
      int signalCount = 0;
      
      if(!InpUseAlfonso)
      {
         // روش معمولی (پین بار، انگالف، دبل تـاپ/باتم)
         if(InpUsePinBar)
         {
            SignalBar pinSignal = entryManager.DetectPinBarSignal(entryRates, currentIdx, entryTrend);
            if(pinSignal.type != SIGNAL_NONE) signals[signalCount++] = pinSignal;
         }
         if(InpUseEngulfing)
         {
            SignalBar engulfSignal = entryManager.DetectEngulfingSignal(entryRates, currentIdx);
            if(engulfSignal.type != SIGNAL_NONE) signals[signalCount++] = engulfSignal;
         }
         if(InpUseDoubleTopBottom)
         {
            SignalBar dtSignal = entryManager.DetectDoubleTopBottom(entryRates, currentIdx, 30);
            if(dtSignal.type != SIGNAL_NONE) signals[signalCount++] = dtSignal;
         }
      }
      else
      {
         // روش آلفونسو
         static datetime lastScan = 0;
         if(entryRates[currentIdx].time - lastScan > 3600) // هر ساعت اسکن کن
         {
            alfonso.ScanZones(entryRates, ArraySize(entryRates));
            lastScan = entryRates[currentIdx].time;
         }
         
         ENUM_TREND_DIRECTION higherTrend = AnalyzeHigherTimeframeTrend();
         SignalBar alfSignal = alfonso.DetectSignal(entryRates, currentIdx, higherTrend);
         if(alfSignal.type != SIGNAL_NONE)
            signals[signalCount++] = alfSignal;
      }
      
      if(signalCount > 0)
      {
         bestSignal = entryManager.SelectBestSignal(signals, signalCount);
         totalSignals++;
      }
      
      return bestSignal;
   }
   
   bool ConfirmSignal(const SignalBar &signal)
   {
      if(signal.type == SIGNAL_NONE || signal.strength < InpMinSignalStrength)
         return false;
      
      ENUM_TREND_DIRECTION signalDirection = signal.isLong ? TREND_UP : TREND_DOWN;
      if(!IsAlignedWithHigherTimeframe(signalDirection))
      {
         Print("❌ سیگنال رد شد - خلاف جهت تایم فریم بالاتر");
         return false;
      }
      
      int confirmIdx = ArraySize(entryRates) - 1;
      if(!entryManager.IsConfirmationCandle(entryRates, confirmIdx, signal))
      {
         Print("⏳ سیگنال در انتظار - منتظر کندل تأیید");
         return false;
      }
      
      Print("✅ سیگنال تأیید شد - قدرت: ", signal.strength);
      return true;
   }
   
   string GetSignalTypeString(ENUM_SIGNAL_TYPE signalType)
   {
      switch(signalType)
      {
         case SIGNAL_PINBAR:           return "پین بار";
         case SIGNAL_ENGULFING:        return "انگالف";
         case SIGNAL_DOUBLE_TOP:       return "سقف دوقلو";
         case SIGNAL_DOUBLE_BOTTOM:    return "کف دوقلو";
         case SIGNAL_BREAKOUT_PULLBACK: return "بریک‌اوت + پولبک";
         default:                      return "نامشخص";
      }
   }
   
   bool CanTrade()
   {
      if(!InpEnableTrading) return false;
      if(!IsMarketOpenForTrading()) return false;
      if(!dayManager.IsTodayTradeable()) return false;
      return true;
   }
   
   bool ExecuteTrade(const SignalBar &signal)
   {
      if(!CanTrade()) return false;
      if(!riskManager.CanOpenNewPosition()) return false;
      if(riskManager.IsDailyRiskExceeded()) return false;
      
      double volume = riskManager.CalculatePositionSize(signal.entryPrice, signal.stopLoss, InpRiskPerTrade);
      if(volume <= 0) return false;
      
      TradeSetup setup = riskManager.CreateTradeSetup(signal, volume);
      
      if(InpUseEMA && InpUseEMAAsTarget && setup.takeProfit1 == 0)
      {
         double emaTarget = maManager.SuggestTakeProfitWithEMA50(signal.entryPrice, signal.isLong);
         if(emaTarget > 0) setup.takeProfit1 = emaTarget;
      }
      
      if(!setup.isValid) return false;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = setup.initialSize;
      request.type = setup.isLong ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      request.price = setup.isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      request.sl = setup.stopLoss;
      request.tp = setup.takeProfit1;
      request.deviation = 10;
      request.magic = InpMagicNumber;
      request.comment = InpTradeComment + " V3.11";
      
      if(!OrderSend(request, result))
      {
         Print("❌ خطا در ارسال معامله: ", result.retcode);
         if(result.retcode == 10027 || result.retcode == 130 || result.retcode == 138)
         {
            Print("⚠️ خطا در ثبت SL - ثبت برای معامله بعدی");
            riskManager.RecordSLFailure();
         }
         return false;
      }
      
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         riskManager.AddPosition(result.order, setup);
         totalTrades++;
         
         TradeObject newTrade;
         MqlDateTime dt;
         TimeToCurrent(dt);
         
         newTrade.tradeEntryPoint = setup.entryPrice;
         newTrade.tradeExitPoint = 0;
         newTrade.tradeprofit = 0;
         newTrade.tradeDay = dt.year * 10000 + dt.mon * 100 + dt.day;
         newTrade.tradeTime = StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);
         newTrade.tradeVolume = setup.initialSize;
         newTrade.tradeDirection = setup.isLong ? "BUY" : "SELL";
         newTrade.tradeStatus = "OPEN";
         newTrade.tradeEntryMoney = (setup.entryPrice * setup.initialSize * tickValue) / tickSize;
         newTrade.tradeExitMoney = 0;
         newTrade.tradePercent = 0;
         newTrade.tradePips = 0;
         newTrade.tradeSignal = GetSignalTypeString(setup.signalType);
         newTrade.tradeMagic = InpMagicNumber;
         
         int tradeId = historyArray.AddTrade(newTrade);
         MapTicketToTradeId(result.order, tradeId);
         
         Print("══════════════════════════════════════════════");
         Print("✅ معامله با موفقیت باز شد - تیکت: ", result.order, " | ID: ", tradeId);
         Print("   تاریخ: ", newTrade.tradeDay, " ", newTrade.tradeTime);
         Print("   جهت: ", newTrade.tradeDirection);
         Print("   حجم: ", newTrade.tradeVolume, " لات");
         Print("   قیمت: ", DoubleToString(newTrade.tradeEntryPoint, _Digits));
         Print("   SL: ", DoubleToString(setup.stopLoss, _Digits));
         Print("   TP: ", DoubleToString(setup.takeProfit1, _Digits));
         Print("   پول ورود: ", DoubleToString(newTrade.tradeEntryMoney, 2), " USD");
         Print("══════════════════════════════════════════════");
         
         return true;
      }
      
      return false;
   }
   
   void ManageOpenPositions()
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? bid : ask;
               
               if(InpUseTrailingStop)
                  riskManager.UpdateTrailingStop(i, currentPrice);
               if(InpUseBreakeven)
                  riskManager.MoveToBreakeven(i, currentPrice);
            }
         }
      }
   }
   
   void UpdateTradeInHistory(ulong ticket, double exitPrice, double profit, datetime exitTime)
   {
      int tradeId = GetTradeIdFromTicket(ticket);
      if(tradeId == 0) return;
      
      if(PositionSelectByTicket(ticket))
      {
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double volume = PositionGetDouble(POSITION_VOLUME);
         bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
         
         double pips = (isLong ? 1 : -1) * MathAbs(exitPrice - entryPrice) / pipValue;
         double exitMoney = (entryPrice * volume * tickValue) / tickSize + profit;
         
         historyArray.UpdateTrade(tradeId, exitPrice, profit, exitMoney, pips, "CLOSED");
         dayManager.RecordTradeResult(profit);
         
         if(InpStopAfterMaxLoss)
            dayManager.CheckAndApplyDailyLossLimit(InpMaxDailyLoss);
      }
   }
   
   void CheckExitSignals()
   {
      if(ArraySize(entryRates) < 10) return;
      
      int currentIdx = ArraySize(entryRates) - 2;
      ENUM_TREND_DIRECTION trend = trendDetector.DetectTrend(entryRates, currentIdx - 20, 20);
      SignalBar reversalSignal = entryManager.DetectPinBarSignal(entryRates, currentIdx, trend, true);
      
      if(reversalSignal.type != SIGNAL_NONE && reversalSignal.strength >= 4)
      {
         Print("⚠️ سیگنال برگشت تشخیص داده شد");
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(PositionSelectByTicket(PositionGetTicket(i)))
            {
               bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
               if((isLong && !reversalSignal.isLong) || (!isLong && reversalSignal.isLong))
               {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  
                  request.action = TRADE_ACTION_DEAL;
                  request.symbol = _Symbol;
                  request.volume = PositionGetDouble(POSITION_VOLUME);
                  request.type = isLong ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                  request.price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  request.deviation = 10;
                  request.magic = InpMagicNumber;
                  request.position = PositionGetTicket(i);
                  request.comment = "Reversal Exit";
                  
                  if(OrderSend(request, result))
                     Print("✅ درخواست خروج ارسال شد - تیکت: ", PositionGetTicket(i));
               }
            }
         }
      }
   }
   
   void SetEntryMode(bool useFullCapital) { riskManager.SetFullCapitalMode(useFullCapital); }
   void RecordSLFailure() { riskManager.RecordSLFailure(); }  // متد دسترسی برای OnTrade
   
   void DisplayMarketStatus()
   {
      CycleInfo mainCycle = GetCurrentMainCycle();
      if(mainCycle.isValid)
      {
         string cycleNames[4] = {"اسپایک", "کانال", "رنج", "نامشخص"};
         string trendNames[4] = {"صعودی", "نزولی", "رنج", "نامشخص"};
         
         Print("══════════════════════════════════════════════");
         Print("📊 تحلیل بازار ", TimeToString(TimeCurrent()));
         Print("⏱️ تایم فریم اصلی: ", EnumToString(InpMainTimeframe));
         Print("🔄 سایکل: ", cycleNames[mainCycle.phase]);
         Print("📈 روند: ", trendNames[mainCycle.trend]);
         
         if(InpCheckMarketHours)
            Print("⏰ ", sessionManager.GetMarketStatusText());
         
         TradeAbleDay* today = dayManager.GetCurrentDay();
         if(today != NULL)
         {
            string status = today.tradeable ? "✅ فعال" : "🚫 متوقف";
            Print("📉 ضرر امروز: ", today.lossCount, " از ", InpMaxDailyLoss, " | وضعیت: ", status);
            Print("💰 سود امروز: ", DoubleToString(today.totalProfit, 2), " USD");
         }
         
         Print("🎯 سیگنال‌های امروز: ", totalSignals, " | معاملات: ", totalTrades);
         Print("══════════════════════════════════════════════");
      }
   }
   
   void OnTick()
   {
      if(!isInitialized)
         if(!Initialize()) return;
      
      if(!RefreshRates()) return;
      
      riskManager.UpdateAccountBalance(AccountInfoDouble(ACCOUNT_BALANCE));
      ManageOpenPositions();
      
      if(dayManager.IsNewDay())
      {
         dayManager.ResetForNewDay();
         Print("📅 روز جدید معاملاتی شروع شد");
      }
      
      // پاکسازی سطوح قدیمی آلفونسو (در صورت فعال بودن)
      if(InpUseAlfonso)
         alfonso.CleanOldZones(TimeCurrent(), InpAlfonsoDaysToKeep);
      
      if(InpUseRSI) CheckRSIDivergence();
      CheckPatterns();
      ShowDailyReport();
      
      datetime currentBarTime = entryRates[ArraySize(entryRates) - 1].time;
      if(currentBarTime == lastBarTime) return;
      lastBarTime = currentBarTime;
      
      DisplayMarketStatus();
      
      if(!dayManager.IsTodayTradeable()) return;
      
      SignalBar signal = FindEntrySignal();
      if(ConfirmSignal(signal))
         ExecuteTrade(signal);
      
      CheckExitSignals();
   }
   
   void PrintMarketSessions() { sessionManager.PrintAllSessions(); }
   void PrintJSON()
   {
      historyArray.PrintAllTradesAsJSON();
      dayManager.PrintAllDaysAsJSON();
   }
};

//+------------------------------------------------------------------+
//| نمونه‌سازی ربات                                                  |
//+------------------------------------------------------------------+
CAlbrooksStyleBot bot;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("══════════════════════════════════════════════");
   Print("🤖 ربات البروکس استایل نسخه 3.11");
   Print("نویسنده: Albrooks Style System");
   Print("تاریخ: ", TimeToString(TimeCurrent()));
   Print("══════════════════════════════════════════════");
   
   bot.SetEntryMode(InpUseFullCapital);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("══════════════════════════════════════════════");
   Print("🛑 ربات غیرفعال شد - کد: ", reason);
   if(InpShowJSONOutput) bot.PrintJSON();
   Print("══════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   bot.OnTick();
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
   HistorySelect(TimeCurrent() - 1, TimeCurrent());
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber)
      {
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         datetime time = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         ulong positionTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         double stopLoss = HistoryDealGetDouble(dealTicket, DEAL_SL);
         
         if(dealEntry == DEAL_ENTRY_OUT)
         {
            if(stopLoss > 0 && MathAbs(price - stopLoss) < 0.0001)
               Print("✅ معامله با SL بسته شد");
            
            Print("🏁 معامله بسته شد - تیکت: ", dealTicket, " | سود: ", DoubleToString(profit, 2), " USD");
            
            if(positionTicket > 0)
               bot.UpdateTradeInHistory(positionTicket, price, profit, time);
         }
         else if(dealEntry == DEAL_ENTRY_IN)
         {
            double orderSL = HistoryDealGetDouble(dealTicket, DEAL_SL);
            if(orderSL == 0 && InpUseForcedSLAfterFailure)
            {
               Print("⚠️ هشدار: SL در این معامله ثبت نشده است!");
               bot.RecordSLFailure();  // استفاده از متد عمومی جدید
            }
         }
         break;
      }
   }
}
//+------------------------------------------------------------------+