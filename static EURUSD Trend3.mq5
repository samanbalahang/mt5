//+------------------------------------------------------------------+
//|                 tatic EURUSD Trend3       |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

//================ INPUTS =================
input string   STRAT_SETTINGS     = "=== STRATEGY SETTINGS ===";
input double   RiskPercent        = 1.0;
input double   MaxLot             = 0.5;
input double   MaxSpreadPips      = 2.5;
input int      CooldownBars       = 1;
input bool     EnableLogging      = true;

//================ INDICATOR SETTINGS =================
input string   IND_SETTINGS       = "=== INDICATOR SETTINGS ===";
input int      EMA_FAST           = 50;     // EMA50
input int      EMA_SLOW           = 200;    // EMA200
input int      RSI_PERIOD         = 14;
input int      ATR_PERIOD         = 14;
input double   RSI_BUY_LEVEL      = 50;     // تغییر از 55 به 50
input double   RSI_SELL_LEVEL     = 50;     // تغییر از 45 به 50
input double   ADX_THRESHOLD      = 25;     // فیلتر روند ضعیف

//================ STOP LOSS SETTINGS =================
input string   SL_SETTINGS        = "=== STOP LOSS SETTINGS ===";
input double   SL_EMA_BUFFER_ATR  = 0.35;    // 30% ATR بافر
input double   SL_MIN_PIPS        = 20;     // حداقل 20 پیپ فاصله

//================ TAKE PROFIT SETTINGS =================
input string   TP_SETTINGS        = "=== TAKE PROFIT SETTINGS ===";
input double   TP_ATR_MULT        = 2.0;    // کاهش از 3.2 به 2.5
input double   TP_EMA_MULT        = 2.0;    // ضریب فاصله از EMA

//================ TRAILING SETTINGS =================
input string   TRAIL_SETTINGS     = "=== TRAILING STOP SETTINGS ===";
input bool     UseTrailingStop    = true;
input double   TrailActivation    = 0.4;    // 40% سود - کاهش از 50%
input double   TrailPercent       = 0.55;    // 60% از موج - کاهش از 70%
input double   TrailEMA_BufferATR = 0.5;    // 50% ATR بافر برای تریل
input int      TrailSensitivity   = 1;      // تایید با 1 کندل
input bool     UseBreakeven       = true;
input double   BreakevenPercent   = 0.2;    // 20% سود - کاهش از 30%

//================ NEWS & TIME FILTERS =================
input string   FILTER_SETTINGS    = "=== FILTER SETTINGS ===";
input bool     UseTimeFilter      = true;
input int      StartHour         = 8;      // 8 صبح لندن
input int      EndHour           = 20;     // 8 عصر نیویورک
input bool     UseVolumeFilter   = true;
input double   VolumeThreshold   = 1.5;    // 1.5 برابر میانگین

//================ GLOBALS =================
int ema50Handle, ema200Handle, rsiHandle, atrHandle, adxHandle;
datetime lastTradeBar = 0;
double avgVolume = 0;

// ساختار پیشرفته برای مدیریت چند پوزیشن
struct PositionData
{
   ulong   ticket;
   double  entryPrice;
   double  ema50AtEntry;
   double  ema200AtEntry;
   double  highestPrice;
   double  lowestPrice;
   double  initialSL;
   double  initialTP;
   double  atrAtEntry;
   bool    isBuy;
   bool    breakevenActivated;
   bool    trailingActivated;
   int     trailConfirmCount;
   double  lastTrailPrice;
   datetime entryTime;
};

PositionData currentPositions[]; // آرایه برای پشتیبانی از چند معامله

//+------------------------------------------------------------------+
int OnInit()
{
   // اصلاح نام هندل‌ها
   ema50Handle = iMA(_Symbol, _Period, EMA_FAST, 0, MODE_EMA, PRICE_CLOSE);
   ema200Handle = iMA(_Symbol, _Period, EMA_SLOW, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, _Period, RSI_PERIOD, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, _Period, ATR_PERIOD);
   adxHandle = iADX(_Symbol, _Period, 14);
   
   ArrayResize(currentPositions, 10); // حداکثر 10 پوزیشن همزمان
   
   if(EnableLogging)
   {
      Print("═══════════════════════════════════════════");
      Print("🚀 EURUSD Trend3 - Advanced Edition Loaded");
      Print("✅ EMA50 Trailing (ATR Adaptive)");
      Print("✅ RSI 50 Level - Reduced False Signals");
      Print("✅ News Event Protection");
      Print("✅ Volume Filter");
      Print("✅ Multi-Position Support");
      Print("═══════════════════════════════════════════");
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(EnableLogging)
      Print("🛑 ربات متوقف شد - کد: ", reason);
}

//+------------------------------------------------------------------+
double GetATR(int shift)
{
   double atr[1];
   if(CopyBuffer(atrHandle, 0, shift, 1, atr) > 0)
      return atr[0];
   return 0;
}

//+------------------------------------------------------------------+
double GetEMA50(int shift)
{
   double ema[1];
   if(CopyBuffer(ema50Handle, 0, shift, 1, ema) > 0)
      return ema[0];
   return 0;
}

//+------------------------------------------------------------------+
double GetEMA200(int shift)
{
   double ema[1];
   if(CopyBuffer(ema200Handle, 0, shift, 1, ema) > 0)
      return ema[0];
   return 0;
}

//+------------------------------------------------------------------+
double GetRSI(int shift)
{
   double rsi[1];
   if(CopyBuffer(rsiHandle, 0, shift, 1, rsi) > 0)
      return rsi[0];
   return 50;
}

//+------------------------------------------------------------------+
double GetADX(int shift)
{
   double adx[1];
   if(CopyBuffer(adxHandle, 0, shift, 1, adx) > 0)
      return adx[0];
   return 0;
}

//+------------------------------------------------------------------+
double GetLot(double slPips)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipValue = (tickValue / tickSize) * _Point;
   
   if(slPips <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   double lot = riskMoney / (slPips * pipValue);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   lot = MathMin(lot, MaxLot);
   lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   
   return lot;
}

//+------------------------------------------------------------------+
bool SpreadOK()
{
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spreadPips = spreadPoints * _Point;
   return (spreadPips <= MaxSpreadPips);
}

//+------------------------------------------------------------------+
bool IsTradingTime()
{
   if(!UseTimeFilter) return true;
   
   datetime currentTime = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(currentTime, tm);
   
   int currentHour = tm.hour;
   int currentDay = tm.day_of_week;
   
   // معامله نکن در تعطیلات آخر هفته
   if(currentDay == 0 || currentDay == 6) return false;
   
   return (currentHour >= StartHour && currentHour <= EndHour);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool IsVolumeOK()
{
   if(!UseVolumeFilter) return true;
   
   long currentVolume = iVolume(_Symbol, _Period, 1);
   
   // محاسبه میانگین حجم 20 کندل اخیر
   if(avgVolume == 0)
   {
      long totalVolume = 0;
      for(int i = 1; i <= 20; i++)
         totalVolume += iVolume(_Symbol, _Period, i);
      
      // راه حل 1: تبدیل صریح به double
      avgVolume = (double)totalVolume / 20.0;
      
      // یا راه حل 2: استفاده از متغیر double جداگانه
      // double avgVolumeDouble = totalVolume / 20.0;
      // avgVolume = avgVolumeDouble;
   }
   
   return (currentVolume >= avgVolume * VolumeThreshold);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool IsNewsEvent()
{
   // تشخیص سریع نوسانات غیرعادی
   double atrCurrent = GetATR(0);
   double atrPrevious = GetATR(1);
   double atrAverage = GetATR(10);
   
   // اگر ATR فعلی 2 برابر میانگین باشد
   if(atrCurrent > atrAverage * 2 && atrPrevious > atrAverage * 1.5)
   {
      if(EnableLogging) Print("⚠️ اخبار مهم تشخیص داده شد - معامله غیرفعال");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
double CalculateEMAStop(bool isBuy, double entryPrice, double ema50Value, double atrValue)
{
   double stopLevel;
   
   // استفاده از ATR برای تنظیم بافر داینامیک
   double buffer = atrValue * SL_EMA_BUFFER_ATR;
   double minStopDistance = SL_MIN_PIPS * _Point;
   
   if(isBuy)
   {
      stopLevel = ema50Value - buffer;
      
      // اطمینان از حداقل فاصله
      if(stopLevel >= entryPrice - minStopDistance)
         stopLevel = entryPrice - minStopDistance;
   }
   else
   {
      stopLevel = ema50Value + buffer;
      
      if(stopLevel <= entryPrice + minStopDistance)
         stopLevel = entryPrice + minStopDistance;
   }
   
   return stopLevel;
}

//+------------------------------------------------------------------+
double CalculateDynamicTP(bool isBuy, double entryPrice, double ema50Value, double atrValue)
{
   double tpLevel;
   double emaDistance = MathAbs(entryPrice - ema50Value);
   
   // ترکیب ATR و فاصله EMA برای TP
   double minTPDistance = MathMax(emaDistance * TP_EMA_MULT, atrValue * TP_ATR_MULT);
   
   if(isBuy)
      tpLevel = entryPrice + minTPDistance;
   else
      tpLevel = entryPrice - minTPDistance;
   
   return tpLevel;
}

//+------------------------------------------------------------------+
double CalculateAdaptiveTrailStop(bool isBuy, double currentPrice, double ema50Value, 
                                 double atrValue, double highestPrice, double lowestPrice,
                                 double entryPrice, double initialTP)
{
   double newSL = 0;
   double profitPercent = 0;
   
   // محاسبه درصد سود
   if(isBuy)
   {
      profitPercent = (currentPrice - entryPrice) / (initialTP - entryPrice);
      
      // بررسی فعالسازی تریلینگ
      if(profitPercent >= TrailActivation)
      {
         // تریل بر اساس EMA50 با بافر ATR (پایدارتر)
         double emaTrail = ema50Value - (atrValue * TrailEMA_BufferATR);
         
         // تریل بر اساس درصد موج
         double percentTrail = currentPrice - ((currentPrice - entryPrice) * TrailPercent);
         
         // ترکیب هوشمند - انتخاب بالاترین مقدار با محدودیت
         newSL = MathMax(emaTrail, percentTrail);
         
         // محدودیت: استاپ جدید نباید از بالاترین قیمت - بافر کمتر باشد
         double maxTrail = highestPrice - (atrValue * 0.2);
         newSL = MathMin(newSL, maxTrail);
         
         // حداقل فاصله از EMA
         double minDistance = atrValue * 0.2;
         if(newSL > ema50Value - minDistance)
            newSL = ema50Value - minDistance;
      }
   }
   else
   {
      profitPercent = (entryPrice - currentPrice) / (entryPrice - initialTP);
      
      if(profitPercent >= TrailActivation)
      {
         double emaTrail = ema50Value + (atrValue * TrailEMA_BufferATR);
         double percentTrail = currentPrice + ((entryPrice - currentPrice) * TrailPercent);
         
         newSL = MathMin(emaTrail, percentTrail);
         
         double minTrail = lowestPrice + (atrValue * 0.2);
         newSL = MathMax(newSL, minTrail);
         
         double minDistance = atrValue * 0.2;
         if(newSL < ema50Value + minDistance)
            newSL = ema50Value + minDistance;
      }
   }
   
   return newSL;
}

//+------------------------------------------------------------------+
bool IsSignalConfirmed(int type)
{
   double adxValue = GetADX(1);
   if(adxValue < ADX_THRESHOLD) return false; // روند ضعیف
   
   // تایید حجم
   if(!IsVolumeOK()) return false;
   
   return true;
}

//+------------------------------------------------------------------+
int FindPositionByTicket(ulong ticket)
{
   for(int i = 0; i < ArraySize(currentPositions); i++)
   {
      if(currentPositions[i].ticket == ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
void AddPosition(PositionData &pos)
{
   for(int i = 0; i < ArraySize(currentPositions); i++)
   {
      if(currentPositions[i].ticket == 0)
      {
         currentPositions[i] = pos;
         break;
      }
   }
}

//+------------------------------------------------------------------+
void RemovePosition(ulong ticket)
{
   for(int i = 0; i < ArraySize(currentPositions); i++)
   {
      if(currentPositions[i].ticket == ticket)
      {
         ZeroMemory(currentPositions[i]);
         break;
      }
   }
}

//+------------------------------------------------------------------+
void UpdateAllTrailingStops()
{
   if(!UseTrailingStop) return;
   
   for(int i = 0; i < ArraySize(currentPositions); i++)
   {
      if(currentPositions[i].ticket == 0) continue;
      
      if(PositionSelectByTicket(currentPositions[i].ticket))
      {
         UpdateSingleTrailingStop(i);
      }
      else
      {
         RemovePosition(currentPositions[i].ticket);
      }
   }
}

//+------------------------------------------------------------------+
void UpdateSingleTrailingStop(int index)
{
   PositionData pos = currentPositions[index];
   
   if(!PositionSelectByTicket(pos.ticket)) return;
   
   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentSL = PositionGetDouble(POSITION_SL);
   
   // به‌روزرسانی بالاترین/پایین‌ترین قیمت
   if(isBuy)
   {
      if(currentPrice > pos.highestPrice)
         pos.highestPrice = currentPrice;
   }
   else
   {
      if(currentPrice < pos.lowestPrice)
         pos.lowestPrice = currentPrice;
   }
   
   // دریافت EMA50 و ATR فعلی (استفاده از کندل 1 برای پایداری بیشتر)
   double currentEMA50 = GetEMA50(1);
   double currentATR = GetATR(0);
   if(currentEMA50 <= 0 || currentATR <= 0) return;
   
   // محاسبه تریل استاپ جدید
   double newSL = CalculateAdaptiveTrailStop(isBuy, currentPrice, currentEMA50, currentATR,
                                            pos.highestPrice, pos.lowestPrice,
                                            pos.entryPrice, pos.initialTP);
   
   // بررسی بریک ایون
   if(UseBreakeven && !pos.breakevenActivated)
   {
      double breakevenLevel;
      if(isBuy)
      {
         breakevenLevel = pos.entryPrice + (pos.initialTP - pos.entryPrice) * BreakevenPercent;
         if(currentPrice >= breakevenLevel)
         {
            newSL = MathMax(newSL, pos.entryPrice + (_Point * 10));
            pos.breakevenActivated = true;
            if(EnableLogging) Print("🛡️ بریک ایون فعال شد - تیکت: ", pos.ticket);
         }
      }
      else
      {
         breakevenLevel = pos.entryPrice - (pos.entryPrice - pos.initialTP) * BreakevenPercent;
         if(currentPrice <= breakevenLevel)
         {
            newSL = MathMin(newSL, pos.entryPrice - (_Point * 10));
            pos.breakevenActivated = true;
            if(EnableLogging) Print("🛡️ بریک ایون فعال شد - تیکت: ", pos.ticket);
         }
      }
   }
   
   // سیستم تایید کندل
   if(pos.trailingActivated || newSL != pos.initialSL)
   {
      if(MathAbs(newSL - pos.lastTrailPrice) > _Point * 10)
      {
         pos.trailConfirmCount++;
         
         if(pos.trailConfirmCount >= TrailSensitivity)
         {
            // به‌روزرسانی حد ضرر
            if(isBuy && newSL > currentSL && newSL != 0)
            {
               trade.PositionModify(pos.ticket, newSL, PositionGetDouble(POSITION_TP));
               pos.lastTrailPrice = newSL;
               pos.trailConfirmCount = 0;
               
               if(EnableLogging)
                  Print("📊 تریل استاپ: ", DoubleToString(newSL, _Digits), 
                        " | سود: ", DoubleToString((currentPrice - pos.entryPrice)/_Point, 1), " پیپ");
            }
            else if(!isBuy && newSL < currentSL && newSL != 0)
            {
               trade.PositionModify(pos.ticket, newSL, PositionGetDouble(POSITION_TP));
               pos.lastTrailPrice = newSL;
               pos.trailConfirmCount = 0;
               
               if(EnableLogging)
                  Print("📊 تریل استاپ: ", DoubleToString(newSL, _Digits),
                        " | سود: ", DoubleToString((pos.entryPrice - currentPrice)/_Point, 1), " پیپ");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, _Period, 0);
   
   if(currentBar == lastBar) return;
   lastBar = currentBar;
   
   // فیلتر زمان
   if(!IsTradingTime()) return;
   
   // تشخیص اخبار
   if(IsNewsEvent()) return;
   
   // به‌روزرسانی تریلینگ برای همه پوزیشن‌ها
   UpdateAllTrailingStops();
   
   // بررسی اسپرد
   if(!SpreadOK()) return;
   
   // اگر پوزیشن باز داریم، فقط تریلینگ انجام بده
   if(PositionsTotal() > 0) return;
   
   // کولدون
   if(lastTradeBar != 0)
   {
      int barsPassed = iBarShift(_Symbol, _Period, lastTradeBar);
      if(barsPassed < CooldownBars) return;
   }
   
   // دریافت مقادیر اندیکاتورها
   double ema50[3], ema200[3], rsi[3], atr[1], close[3];
   
   CopyBuffer(ema50Handle, 0, 0, 3, ema50);
   CopyBuffer(ema200Handle, 0, 0, 3, ema200);
   CopyBuffer(rsiHandle, 0, 0, 3, rsi);
   CopyBuffer(atrHandle, 0, 0, 1, atr);
   CopyClose(_Symbol, _Period, 0, 3, close);
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   //================ SIGNAL BUY =================
   if(close[2] < ema50[2] &&      // کندل 2 زیر EMA50
      close[1] > ema50[1] &&      // کندل 1 بالای EMA50 (عبور)
      ema50[1] > ema200[1] &&     // EMA50 > EMA200
      rsi[1] > RSI_BUY_LEVEL &&   // RSI > 50
      IsSignalConfirmed(0))       // تایید با ADX و حجم
   {
      double ema50Value = ema50[1];
      double atrValue = atr[0];
      
      // محاسبه استاپ داینامیک
      double stopLoss = CalculateEMAStop(true, ask, ema50Value, atrValue);
      
      // محاسبه TP
      double takeProfit = CalculateDynamicTP(true, ask, ema50Value, atrValue);
      
      // محاسبه حجم
      double slPips = MathAbs(ask - stopLoss) / _Point;
      double lot = GetLot(slPips);
      
      trade.SetDeviationInPoints(10);
      
      if(trade.Buy(lot, _Symbol, 0, stopLoss, takeProfit))
      {
         lastTradeBar = currentBar;
         
         // ذخیره اطلاعات پوزیشن
         PositionData newPos;
         newPos.ticket = trade.ResultOrder();
         newPos.entryPrice = ask;
         newPos.ema50AtEntry = ema50Value;
         newPos.ema200AtEntry = ema200[1];
         newPos.highestPrice = ask;
         newPos.lowestPrice = ask;
         newPos.initialSL = stopLoss;
         newPos.initialTP = takeProfit;
         newPos.atrAtEntry = atrValue;
         newPos.isBuy = true;
         newPos.breakevenActivated = false;
         newPos.trailingActivated = false;
         newPos.trailConfirmCount = 0;
         newPos.lastTrailPrice = stopLoss;
         newPos.entryTime = TimeCurrent();
         
         AddPosition(newPos);
         
         if(EnableLogging)
         {
            Print("═══════════════════════════════════════════");
            Print("🚀 خرید باز شد - تیکت: ", newPos.ticket);
            Print("💰 حجم: ", lot);
            Print("🎯 SL: ", DoubleToString(stopLoss, _Digits), 
                  " (", DoubleToString(slPips, 1), " پیپ)");
            Print("✨ TP: ", DoubleToString(takeProfit, _Digits));
            Print("📊 فاصله تا EMA50: ", DoubleToString(MathAbs(ask - ema50Value)/_Point, 1), " پیپ");
            Print("📈 ATR: ", DoubleToString(atrValue/_Point, 1), " پیپ");
            Print("═══════════════════════════════════════════");
         }
      }
   }
   
   //================ SIGNAL SELL =================
   if(close[2] > ema50[2] &&      // کندل 2 بالای EMA50
      close[1] < ema50[1] &&      // کندل 1 زیر EMA50 (شکست)
      ema50[1] < ema200[1] &&     // EMA50 < EMA200
      rsi[1] < RSI_SELL_LEVEL &&  // RSI < 50
      IsSignalConfirmed(1))       // تایید با ADX و حجم
   {
      double ema50Value = ema50[1];
      double atrValue = atr[0];
      
      double stopLoss = CalculateEMAStop(false, bid, ema50Value, atrValue);
      double takeProfit = CalculateDynamicTP(false, bid, ema50Value, atrValue);
      
      double slPips = MathAbs(stopLoss - bid) / _Point;
      double lot = GetLot(slPips);
      
      trade.SetDeviationInPoints(10);
      
      if(trade.Sell(lot, _Symbol, 0, stopLoss, takeProfit))
      {
         lastTradeBar = currentBar;
         
         PositionData newPos;
         newPos.ticket = trade.ResultOrder();
         newPos.entryPrice = bid;
         newPos.ema50AtEntry = ema50Value;
         newPos.ema200AtEntry = ema200[1];
         newPos.highestPrice = bid;
         newPos.lowestPrice = bid;
         newPos.initialSL = stopLoss;
         newPos.initialTP = takeProfit;
         newPos.atrAtEntry = atrValue;
         newPos.isBuy = false;
         newPos.breakevenActivated = false;
         newPos.trailingActivated = false;
         newPos.trailConfirmCount = 0;
         newPos.lastTrailPrice = stopLoss;
         newPos.entryTime = TimeCurrent();
         
         AddPosition(newPos);
         
         if(EnableLogging)
         {
            Print("═══════════════════════════════════════════");
            Print("🚀 فروش باز شد - تیکت: ", newPos.ticket);
            Print("💰 حجم: ", lot);
            Print("🎯 SL: ", DoubleToString(stopLoss, _Digits),
                  " (", DoubleToString(slPips, 1), " پیپ)");
            Print("✨ TP: ", DoubleToString(takeProfit, _Digits));
            Print("📊 فاصله تا EMA50: ", DoubleToString(MathAbs(bid - ema50Value)/_Point, 1), " پیپ");
            Print("📈 ATR: ", DoubleToString(atrValue/_Point, 1), " پیپ");
            Print("═══════════════════════════════════════════");
         }
      }
   }
}

//+------------------------------------------------------------------+
void OnTradeAction(const CTrade &action)
{
   // اگر یک معامله انجام شده
   if(action.ResultDeal() != 0)
   {
      ulong ticket = action.ResultOrder();
      
      // فقط بررسی کن که آیا پوزیشن هنوز باز است یا نه
      // اگر پوزیشن بسته شده باشد، PositionSelectByTicket برمی‌گرداند false
      if(!PositionSelectByTicket(ticket))
      {
         RemovePosition(ticket);
         if(EnableLogging) 
            Print("✅ پوزیشن بسته شد - تیکت: ", ticket);
      }
   }
}
//+------------------------------------------------------------------+
