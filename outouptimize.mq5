//+------------------------------------------------------------------+
//| EURUSD Trend Shift AI - Self Learning EA (MT5) - OPTIMIZED      |
//+------------------------------------------------------------------+
#property copyright "Optimized Version"
#property description "EURUSD Trend Shift AI with Min_Score parameter"
#property description "Ready for parameter optimization"
#property version   "4.0"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//================ SETTINGS =================
input double BaseLot   = 0.03;
input double MaxLot    = 0.05;

input int MA_Fast = 50;
input int MA_Slow = 200;
input int RSI_Period = 14;
input int ATR_Period = 14;
input double ATR_Mult = 2.0;
input double TP_Mult = 1.5;

input double BE_Pips = 20;
input double Trail_Pips = 30;
input double Trail_Step = 5;

// پارامتر جدید برای بهینه‌سازی
input int Min_Score = 25;  // حداقل امتیاز برای ورود (1 تا 100)

input bool EnableLogging = true;

//================ AI MEMORY =================
int BuyWin=0, BuyLoss=0;
int SellWin=0, SellLoss=0;
int ConsecutiveLoss=0;

//================ INDICATOR HANDLES =========
int ma_fast_handle = INVALID_HANDLE;
int ma_slow_handle = INVALID_HANDLE;
int rsi_handle = INVALID_HANDLE;
int atr_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ma_fast_handle = iMA(_Symbol, _Period, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   ma_slow_handle = iMA(_Symbol, _Period, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   atr_handle = iATR(_Symbol, _Period, ATR_Period);
   
   if(ma_fast_handle == INVALID_HANDLE || ma_slow_handle == INVALID_HANDLE || 
      rsi_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE)
   {
      Print("Error: Failed to create indicator handles!");
      return(INIT_FAILED);
   }
   
   if(EnableLogging) Print("EA initialized. Min_Score=", Min_Score);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ma_fast_handle != INVALID_HANDLE) IndicatorRelease(ma_fast_handle);
   if(ma_slow_handle != INVALID_HANDLE) IndicatorRelease(ma_slow_handle);
   if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
}

//+------------------------------------------------------------------+
//| Calculate AI Strength Factor                                     |
//+------------------------------------------------------------------+
double AI_Strength()
{
   int total = BuyWin + BuyLoss + SellWin + SellLoss;
   if(total < 5) return 1.0;

   double winrate = double(BuyWin + SellWin) / total;
   double factor = 0.7 + winrate;

   if(ConsecutiveLoss >= 3)
      factor *= 0.7;

   return MathMax(0.5, MathMin(1.5, factor));
}

//+------------------------------------------------------------------+
//| Calculate Buy Signal Score                                       |
//+------------------------------------------------------------------+
int BuyScore(double maFast,double maSlow,double rsi,double atr)
{
   int score = 0;
   if(maFast > maSlow) score += 30;
   if(!MathIsValidNumber(rsi)) rsi = 50;
   if(rsi > 55) score += 20;
   if(atr > _Point*80) score += 15;
   if(BuyWin > BuyLoss) score += 10;
   if(ConsecutiveLoss >= 3) score -= 20;
   return score;
}

//+------------------------------------------------------------------+
//| Calculate Sell Signal Score                                      |
//+------------------------------------------------------------------+
int SellScore(double maFast,double maSlow,double rsi,double atr)
{
   int score = 0;
   if(maFast < maSlow) score += 30;
   if(!MathIsValidNumber(rsi)) rsi = 50;
   if(rsi < 45) score += 20;
   if(atr > _Point*80) score += 15;
   if(SellWin > SellLoss) score += 10;
   if(ConsecutiveLoss >= 3) score -= 20;
   return score;
}

//+------------------------------------------------------------------+
//| Check if EURUSD position exists                                  |
//+------------------------------------------------------------------+
bool HasEURUSDPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         if(symbol == "EURUSD") return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage open trades with trailing stop                            |
//+------------------------------------------------------------------+
void ManageTrade()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != "EURUSD") continue;
      
      long type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double currentPrice = 0;
      
      if(type == POSITION_TYPE_BUY)
         currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
      else if(type == POSITION_TYPE_SELL)
         currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
      else continue;
      
      // Calculate profit in pips
      double profitPoints = 0;
      if(type == POSITION_TYPE_BUY)
         profitPoints = (currentPrice - open) / _Point;
      else if(type == POSITION_TYPE_SELL)
         profitPoints = (open - currentPrice) / _Point;
      
      // Break Even Logic
      if(profitPoints >= BE_Pips && (sl < open - 10*_Point || sl > open + 10*_Point))
      {
         double newSL = open;
         if(type == POSITION_TYPE_BUY) newSL = open + 2*_Point;
         else if(type == POSITION_TYPE_SELL) newSL = open - 2*_Point;
         
         newSL = NormalizeDouble(newSL, _Digits);
         if(!trade.PositionModify(ticket, newSL, tp))
         {
            if(EnableLogging) Print("Failed to modify BE. Error: ", GetLastError());
         }
      }
      
      // Trailing Stop Logic
      if(profitPoints >= Trail_Pips)
      {
         double stepPoints = Trail_Step * 10 * _Point;
        
         double newSL = sl;
         if(type == POSITION_TYPE_BUY)
         {
            newSL = currentPrice - stepPoints;
            if(newSL > sl + _Point)
            {
               newSL = NormalizeDouble(newSL, _Digits);
               if(!trade.PositionModify(ticket, newSL, tp))
               {
                  if(EnableLogging) Print("Failed to modify trailing. Error: ", GetLastError());
               }
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            newSL = currentPrice + stepPoints;
            if(newSL < sl - _Point)
            {
               newSL = NormalizeDouble(newSL, _Digits);
               if(!trade.PositionModify(ticket, newSL, tp))
               {
                  if(EnableLogging) Print("Failed to modify trailing. Error: ", GetLastError());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Main tick function (CORRECTED INDICES)                           |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, _Period, 0);
   
   if(lastBar == currentBar) return;
   lastBar = currentBar;
   
   if(Symbol() != "EURUSD") 
   {
      if(EnableLogging) Print("EA only works on EURUSD");
      return;
   }
   
   ManageTrade();
   
   if(HasEURUSDPosition()) 
   {
      if(EnableLogging) Print("Position exists, skipping");
      return;
   }
   
   double maFastArray[], maSlowArray[], rsiArray[], atrArray[], closeArray[];
   
   ArraySetAsSeries(maFastArray, true);
   ArraySetAsSeries(maSlowArray, true);
   ArraySetAsSeries(rsiArray, true);
   ArraySetAsSeries(atrArray, true);
   ArraySetAsSeries(closeArray, true);
   
   // دریافت 4 کندل برای بررسی صحیح کراس
   int copied_fast = CopyBuffer(ma_fast_handle, 0, 0, 4, maFastArray);
   int copied_slow = CopyBuffer(ma_slow_handle, 0, 0, 4, maSlowArray);
   int copied_rsi = CopyBuffer(rsi_handle, 0, 0, 4, rsiArray);
   int copied_atr = CopyBuffer(atr_handle, 0, 0, 4, atrArray);
   int copied_close = CopyClose(_Symbol, _Period, 0, 4, closeArray);
   
   if(copied_fast < 4 || copied_slow < 4 || copied_rsi < 4 || 
      copied_atr < 4 || copied_close < 4)
   {
      if(EnableLogging) Print("Indicator data incomplete");
      return;
   }
   
   // ایندکس‌های اصلاح شده برای تشخیص صحیح کراس
   // آرایه سری شده: [0]=کنونی, [1]=یک کندل قبل, [2]=دو کندل قبل, [3]=سه کندل قبل
   double close2 = closeArray[2];  // دو کندل قبل
   double close1 = closeArray[1];  // یک کندل قبل  
   double close0 = closeArray[0];  // کندل کنونی (در حال تشکیل)
   double maFast = maFastArray[1]; // MA در کندل قبل (کندل کامل شده)
   double maSlow = maSlowArray[1]; // MA در کندل قبل
   double rsi = rsiArray[1];       // RSI در کندل قبل
   double atr = atrArray[1];       // ATR در کندل قبل
   
   if(!MathIsValidNumber(maFast) || !MathIsValidNumber(maSlow) || 
      !MathIsValidNumber(rsi) || !MathIsValidNumber(atr))
   {
      return;
   }
   
   double ai = AI_Strength();
   double lot = BaseLot * ai;
   if(lot > MaxLot) lot = MaxLot;
   lot = NormalizeDouble(lot, 2);
   
   double minlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < minlot) lot = minlot;
   
   // ===== BUY SIGNAL =====
   // شرط کراس: کندل قبل از MA پایین‌تر بود، کندل جاری از MA بالاتر است
   bool buyCrossCondition = (close2 < maFast && close1 > maFast);
   int buyScoreValue = BuyScore(maFast, maSlow, rsi, atr);
   
   if(buyCrossCondition && buyScoreValue >= Min_Score)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      double stopDistance = atr * ATR_Mult;
      double sl = bid - stopDistance;
      sl = NormalizeDouble(sl, _Digits);
      
      double takeProfitDistance = atr * TP_Mult;
      double tp = bid + takeProfitDistance;
      tp = NormalizeDouble(tp, _Digits);
      
      // اعتبارسنجی فاصله حد ضرر
      long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minStop = (double)stopsLevel * _Point;
      if((bid - sl) < minStop)
      {
         sl = bid - minStop - 10*_Point;
         sl = NormalizeDouble(sl, _Digits);
      }
      
      // اعتبارسنجی حد سود
      double minTP = 10 * _Point;
      if((tp - bid) < minTP)
      {
         tp = bid + minTP;
         tp = NormalizeDouble(tp, _Digits);
      }
      
      if(EnableLogging) 
      {
         Print("BUY: Lot=", lot, " Price=", bid, " SL=", sl, " TP=", tp,
               " Score=", buyScoreValue, "/", Min_Score);
      }
      
      if(!trade.Buy(lot, _Symbol, 0, sl, tp, "AI BUY"))
      {
         Print("Buy failed. Error: ", GetLastError());
      }
      return;
   }
   
   // ===== SELL SIGNAL =====
   bool sellCrossCondition = (close2 > maFast && close1 < maFast);
   int sellScoreValue = SellScore(maFast, maSlow, rsi, atr);
   
   if(sellCrossCondition && sellScoreValue >= Min_Score)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double stopDistance = atr * ATR_Mult;
      double sl = ask + stopDistance;
      sl = NormalizeDouble(sl, _Digits);
      
      double takeProfitDistance = atr * TP_Mult;
      double tp = ask - takeProfitDistance;
      tp = NormalizeDouble(tp, _Digits);
      
      long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minStop = (double)stopsLevel * _Point;
      if((sl - ask) < minStop)
      {
         sl = ask + minStop + 10*_Point;
         sl = NormalizeDouble(sl, _Digits);
      }
      
      double minTP = 10 * _Point;
      if((ask - tp) < minTP)
      {
         tp = ask - minTP;
         tp = NormalizeDouble(tp, _Digits);
      }
      
      if(EnableLogging) 
      {
         Print("SELL: Lot=", lot, " Price=", ask, " SL=", sl, " TP=", tp,
               " Score=", sellScoreValue, "/", Min_Score);
      }
      
      if(!trade.Sell(lot, _Symbol, 0, sl, tp, "AI SELL"))
      {
         Print("Sell failed. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
         ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         
         if(entry == DEAL_ENTRY_OUT)
         {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
            
            if(profit > 0)
            {
               ConsecutiveLoss = 0;
               if(posType == POSITION_TYPE_BUY) BuyWin++;
               else if(posType == POSITION_TYPE_SELL) SellWin++;
            }
            else
            {
               ConsecutiveLoss++;
               if(posType == POSITION_TYPE_BUY) BuyLoss++;
               else if(posType == POSITION_TYPE_SELL) SellLoss++;
            }
            
            if(EnableLogging) 
            {
               Print("Trade closed. Profit: ", profit, " ConsecutiveLoss: ", ConsecutiveLoss);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+