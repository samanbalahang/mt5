//+------------------------------------------------------------------+
//| EURUSD Trend Shift AI - Self Learning EA (MT5)                   |
//+------------------------------------------------------------------+
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

input double BE_Pips = 20;
input double Trail_Pips = 30;
input double Trail_Step = 5;

//================ AI MEMORY =================
int BuyWin=0, BuyLoss=0;
int SellWin=0, SellLoss=0;
int ConsecutiveLoss=0;

//--------------------------------------------------
double AI_Strength()
{
   int total = BuyWin + BuyLoss + SellWin + SellLoss;
   if(total < 5) return 1.0;

   double winrate = double(BuyWin + SellWin) / total;
   double factor = 0.7 + winrate;

   if(ConsecutiveLoss >= 3)
      factor *= 0.7; // محافظه‌کار

   return MathMax(0.5, MathMin(1.5, factor));
}

//--------------------------------------------------
int BuyScore(double maFast,double maSlow,double rsi,double atr)
{
   int score = 0;
   if(maFast > maSlow) score += 30;
   if(rsi > 55) score += 20;
   if(atr > _Point*80) score += 15;
   if(BuyWin > BuyLoss) score += 10;
   if(ConsecutiveLoss >= 3) score -= 20;
   return score;
}

//--------------------------------------------------
int SellScore(double maFast,double maSlow,double rsi,double atr)
{
   int score = 0;
   if(maFast < maSlow) score += 30;
   if(rsi < 45) score += 20;
   if(atr > _Point*80) score += 15;
   if(SellWin > SellLoss) score += 10;
   if(ConsecutiveLoss >= 3) score -= 20;
   return score;
}

//--------------------------------------------------
void ManageTrade()
{
   if(!PositionSelect("EURUSD")) return;

   int type = PositionGetInteger(POSITION_TYPE);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl   = PositionGetDouble(POSITION_SL);

   double price = (type==POSITION_TYPE_BUY)
      ? SymbolInfoDouble("EURUSD",SYMBOL_BID)
      : SymbolInfoDouble("EURUSD",SYMBOL_ASK);

   double profitPips = (type==POSITION_TYPE_BUY)
      ? (price-open)/_Point
      : (open-price)/_Point;

   // Break Even
   if(profitPips >= BE_Pips)
   {
      double newSL = (type==POSITION_TYPE_BUY)
         ? open + 2*_Point
         : open - 2*_Point;

      trade.PositionModify("EURUSD",newSL,0);
   }

   // Trailing
   if(profitPips >= Trail_Pips)
   {
      double newSL = (type==POSITION_TYPE_BUY)
         ? sl + Trail_Step*_Point
         : sl - Trail_Step*_Point;

      trade.PositionModify("EURUSD",newSL,0);
   }
}

//--------------------------------------------------
void OnTick()
{
   if(Symbol()!="EURUSD") return;

   ManageTrade();
   if(PositionSelect("EURUSD")) return;

   double maFast = iMA("EURUSD",PERIOD_M15,MA_Fast,0,MODE_EMA,PRICE_CLOSE,1);
   double maSlow = iMA("EURUSD",PERIOD_M15,MA_Slow,0,MODE_EMA,PRICE_CLOSE,1);

   double close1 = iClose("EURUSD",PERIOD_M15,1);
   double close2 = iClose("EURUSD",PERIOD_M15,2);

   double rsi = iRSI("EURUSD",PERIOD_M15,RSI_Period,PRICE_CLOSE,1);
   double atr = iATR("EURUSD",PERIOD_M15,ATR_Period,1);

   double ai = AI_Strength();
   double lot = BaseLot * ai;
   if(lot > MaxLot) lot = MaxLot;

   // ===== BUY =====
   if(close2 < maFast && close1 > maFast &&
      BuyScore(maFast,maSlow,rsi,atr) >= 70)
   {
      double sl = SymbolInfoDouble("EURUSD",SYMBOL_BID) - atr*ATR_Mult;
      trade.Buy(lot,"EURUSD",0,sl,0,"AI BUY");
   }

   // ===== SELL =====
   if(close2 > maFast && close1 < maFast &&
      SellScore(maFast,maSlow,rsi,atr) >= 70)
   {
      double sl = SymbolInfoDouble("EURUSD",SYMBOL_ASK) + atr*ATR_Mult;
      trade.Sell(lot,"EURUSD",0,sl,0,"AI SELL");
   }
}
//--------------------------------------------------
void OnTradeTransaction(const MqlTradeTransaction& t,
                        const MqlTradeRequest& r,
                        const MqlTradeResult& res)
{
   if(t.type==TRADE_TRANSACTION_DEAL_ADD &&
      t.deal_entry==DEAL_ENTRY_OUT)
   {
      if(t.profit > 0)
      {
         ConsecutiveLoss = 0;
         if(t.position_type==POSITION_TYPE_BUY) BuyWin++;
         else SellWin++;
      }
      else
      {
         ConsecutiveLoss++;
         if(t.position_type==POSITION_TYPE_BUY) BuyLoss++;
         else SellLoss++;
      }
   }
}