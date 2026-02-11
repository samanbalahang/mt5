//+------------------------------------------------------------------+
//| second static EURUSD Trend Shift AI v9.1 - Fixed & Clean Version (MT5)       |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

//================ INPUTS =================
input double RiskPercent      = 1.5;
input double MaxLot           = 1.0;
input double ATR_SL_Mult      = 1.8;
input double ATR_TP_Mult      = 3.2;
input double MaxSpreadPips    = 2.5;
input int    CooldownBars     = 1;
input int    EMA_Fast         = 50;
input int    EMA_Slow         = 200;
input int    RSI_Period       = 14;
input int    ATR_Period       = 14;
input bool   EnableLogging    = true;

//================ GLOBALS =================
int emaFastHandle, emaSlowHandle, rsiHandle, atrHandle;
datetime lastTradeBar=0;

//+------------------------------------------------------------------+
int OnInit()
{
   emaFastHandle = iMA(_Symbol,_Period,EMA_Fast,0,MODE_EMA,PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol,_Period,EMA_Slow,0,MODE_EMA,PRICE_CLOSE);
   rsiHandle     = iRSI(_Symbol,_Period,RSI_Period,PRICE_CLOSE);
   atrHandle     = iATR(_Symbol,_Period,ATR_Period);

   if(EnableLogging)
      Print("EURUSD Trend Shift AI v9.1 Loaded");

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
double GetLot(double slPips)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

   double pipValue  = (tickValue/tickSize) * _Point;

   if(slPips <= 0) return(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));

   double lot = riskMoney / (slPips * pipValue);

   double step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot/step) * step;

   lot = MathMin(lot,MaxLot);
   lot = MathMax(lot,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));

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
void OnTick()
{
   static datetime lastBar=0;
   datetime currentBar = iTime(_Symbol,_Period,0);

   if(currentBar == lastBar) return;   // فقط روی کندل جدید
   lastBar = currentBar;

   if(!SpreadOK()) return;

   if(PositionSelect(_Symbol)) return;

   // Cooldown
   if(lastTradeBar!=0)
   {
      int barsPassed = iBarShift(_Symbol,_Period,lastTradeBar);
      if(barsPassed < CooldownBars)
         return;
   }

   double emaFast[3], emaSlow[3], rsi[3], atr[3], close[3];

   CopyBuffer(emaFastHandle,0,0,3,emaFast);
   CopyBuffer(emaSlowHandle,0,0,3,emaSlow);
   CopyBuffer(rsiHandle,0,0,3,rsi);
   CopyBuffer(atrHandle,0,0,3,atr);
   CopyClose(_Symbol,_Period,0,3,close);

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   //================ BUY =================
   if(close[2] < emaFast[2] &&
      close[1] > emaFast[1] &&
      emaFast[1] > emaSlow[1] &&
      rsi[1] > 55)
   {
      double sl = bid - (atr[1] * ATR_SL_Mult);
      double tp = bid + (atr[1] * ATR_TP_Mult);

      double slPips = MathAbs(bid - sl) / _Point;
      double lot = GetLot(slPips);

      trade.SetDeviationInPoints(10);

      if(trade.Buy(lot,_Symbol,0,sl,tp))
      {
         lastTradeBar = currentBar;
         if(EnableLogging) Print("BUY opened | Lot:",lot);
      }
   }

   //================ SELL =================
   if(close[2] > emaFast[2] &&
      close[1] < emaFast[1] &&
      emaFast[1] < emaSlow[1] &&
      rsi[1] < 45)
   {
      double sl = ask + (atr[1] * ATR_SL_Mult);
      double tp = ask - (atr[1] * ATR_TP_Mult);

      double slPips = MathAbs(sl - ask) / _Point;
      double lot = GetLot(slPips);

      trade.SetDeviationInPoints(10);

      if(trade.Sell(lot,_Symbol,0,sl,tp))
      {
         lastTradeBar = currentBar;
         if(EnableLogging) Print("SELL opened | Lot:",lot);
      }
   }
}
//+------------------------------------------------------------------+
