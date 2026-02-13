//+------------------------------------------------------------------+
//|                                         AlBrooks_H2L2_MT5_Final.mq5|
//|                                      استراتژی پرایس اکشن بروکس   |
//|                              نسخه نهایی - فقط لندن و نیویورک     |
//|                                    نسخه 4.3 - مدیریت سرمایه واقعی|
//+------------------------------------------------------------------+
#property copyright "Al Brooks Strategy - London & NY Only"
#property version   "4.30"
#property strict

//+------------------------------------------------------------------+
//| پارامترهای ورودی                                                |
//+------------------------------------------------------------------+
input double   InitialLotSize     = 0.50;        // حجم اولیه معامله (لات)
input int      StopLoss_Pips      = 40;          // حد ضرر (پیپ) - پشتیبان
input int      TakeProfit_Pips    = 60;          // حد سود (پیپ) - پشتیبان
input int      EMA_Period         = 20;          // دوره EMA
input int      EMA_Slow_Period    = 50;          // دوره EMA کند
input int      Max_Spread_Pips    = 20;          // حداکثر اسپرد (پیپ)
input int      Min_Candle_Pips    = 10;          // حداقل اندازه کندل (پیپ)
input int      Magic_Number       = 2525;        // مجیک نامبر
input int      Slippage_Points    = 10;          // اسلیپیج (نقطه)
input int      RSI_Period         = 14;          // دوره RSI
input double   RSI_Overbought     = 70;          // اشباع خرید
input double   RSI_Oversold       = 30;          // اشباع فروش

//+------------------------------------------------------------------+
//| پارامترهای مدیریت سرمایه (مارتینگل معکوس) - اصلاح شده          |
//+------------------------------------------------------------------+
input bool     Use_Money_Management = true;      // فعال‌سازی مدیریت سرمایه
input double   Win_Multiplier       = 1.5;        // ضریب افزایش پس از برد
input double   Loss_Multiplier      = 0.8;        // ضریب کاهش پس از باخت
input int      Max_Lot_Multiplier   = 10;         // حداکثر ضریب حجم
input double   Min_Lot_Absolute     = 0.01;       // حداقل حجم مطلق (هرگز کمتر از این)
input int      Reset_After_Wins     = 5;          // بازگشت به حجم اولیه پس N برد متوالی
input int      Reset_After_Losses   = 3;          // بازگشت به حجم اولیه پس N باخت متوالی

//+------------------------------------------------------------------+
//| پارامترهای محدودیت روزانه                                       |
//+------------------------------------------------------------------+
input int      Max_Daily_Loss      = 3;           // حداکثر باخت مجاز در روز
input bool     Reset_Daily_Loss    = true;        // ریست شمارنده باخت در شروع روز جدید

//+------------------------------------------------------------------+
//| پارامترهای زمان‌بندی بازار لندن و نیویورک                      |
//+------------------------------------------------------------------+
input bool     Use_London_Session = true;        // معامله در بازار لندن
input bool     Use_NY_Session     = true;        // معامله در بازار نیویورک
input bool     Use_Overlap_Session = true;       // معامله در همپوشانی لندن/نیویورک
input int      London_Start_Hour  = 9;           // شروع لندن (GMT+2)
input int      London_End_Hour    = 18;          // پایان لندن (GMT+2)
input int      NY_Start_Hour      = 14;          // شروع نیویورک (GMT+2)
input int      NY_End_Hour        = 23;          // پایان نیویورک (GMT+2)
input bool     Avoid_Friday_Close = true;        // جلوگیری از معامله جمعه شب
input int      Friday_Close_Hour  = 22;          // ساعت توقف معاملات جمعه (GMT+2)

//+------------------------------------------------------------------+
//| ثابت‌ها و تعاریف                                               |
//+------------------------------------------------------------------+
#define MAX_PIVOTS 10
#define MAX_TRADE_HISTORY 50

//+------------------------------------------------------------------+
//| ساختار مدیریت تاریخچه معاملات                                  |
//+------------------------------------------------------------------+
struct TradeRecord {
   ulong ticket;           // شماره تیکت
   datetime open_time;     // زمان باز شدن
   datetime close_time;    // زمان بسته شدن
   double lot_size;        // حجم معامله
   double profit;          // سود/زیان
   bool is_win;            // آیا برنده شده؟
   string comment;         // توضیحات
};

//+------------------------------------------------------------------+
//| ساختار وضعیت مدیریت سرمایه - اصلاح شده                         |
//+------------------------------------------------------------------+
struct MoneyManagementState {
   double current_multiplier;    // ضریب فعلی
   double real_multiplier;       // ضریب واقعی (پس از راند کردن)
   int consecutive_wins;         // بردهای متوالی
   int consecutive_losses;       // باخت‌های متوالی
   double total_profit;          // سود/زیان کل
   int total_trades;            // تعداد کل معاملات
   int win_trades;             // تعداد معاملات برنده
   int loss_trades;            // تعداد معاملات بازنده
   double max_lot_used;        // بیشترین حجم استفاده شده
   double min_lot_used;        // کمترین حجم استفاده شده
   int daily_loss_count;        // تعداد باخت‌های امروز
   datetime last_trade_day;     // تاریخ آخرین معامله
   TradeRecord last_trades[MAX_TRADE_HISTORY]; // آخرین معاملات
};

MoneyManagementState mm_state;

//+------------------------------------------------------------------+
//| ساختار مدیریت تریل استاپ برای هر پوزیشن                        |
//+------------------------------------------------------------------+
struct TrailStopState {
   ulong ticket;              // شماره تیکت
   double entry_price;        // قیمت ورود
   double current_sl;         // حد ضرر فعلی
   double last_doji_level;    // آخرین سطح دوجی
   datetime last_doji_time;   // زمان آخرین دوجی
   double last_target_price;  // آخرین قیمت هدف
   int trail_stage;          // مرحله تریل
   bool is_active;           // فعال بودن
};

TrailStopState trail_states[];

//+------------------------------------------------------------------+
//| تعریف نوع سایکل بازار                                           |
//+------------------------------------------------------------------+
enum MarketCycle {
   CYCLE_BREAKOUT,      // شکست
   CYCLE_NARROW_CHANNEL,// کانال باریک
   CYCLE_WIDE_CHANNEL,  // کانال عریض
   CYCLE_TRADING_RANGE  // رنج
};

//+------------------------------------------------------------------+
//| ساختار ذخیره اطلاعات سایکل                                      |
//+------------------------------------------------------------------+
struct CycleInfo {
   MarketCycle cycle;
   string direction;    // up, down, neutral
   double angle;        // زاویه کانال
   double upper_level;  // سطح بالایی
   double lower_level;  // سطح پایینی
   bool isValid;
};

//+------------------------------------------------------------------+
//| ساختار خط روند                                                  |
//+------------------------------------------------------------------+
struct TrendLine {
   double point1_price;
   double point2_price;
   datetime point1_time;
   datetime point2_time;
   double slope;
   bool isValid;
};

//+------------------------------------------------------------------+
//| ساختار واگرایی RSI                                              |
//+------------------------------------------------------------------+
struct DivergenceInfo {
   bool regular_bullish;
   bool regular_bearish;
   bool hidden_bullish;
   bool hidden_bearish;
   double strength;
};

//+------------------------------------------------------------------+
//| هندل‌های ایندیکاتور                                             |
//+------------------------------------------------------------------+
int ema_handle;
int ema_50_handle;
int atr_handle;
int ema_handle_h1;
int ema_50_handle_h1;
int ema_handle_m15;
int ema_50_handle_m15;
int ema_handle_m5;
int ema_50_handle_m5;
int rsi_handle;
int rsi_handle_h1;
int rsi_handle_m15;
int rsi_handle_m5;

//+------------------------------------------------------------------+
//| تبدیل پیپ به قیمت                                               |
//+------------------------------------------------------------------+
double PipsToPrice(int pips) {
   double pip_value = GetPipValue();
   return pips * pip_value;
}

//+------------------------------------------------------------------+
//| محاسبه ارزش پیپ بر اساس بروکر                                   |
//+------------------------------------------------------------------+
double GetPipValue() {
   return _Point * 10;
}

//+------------------------------------------------------------------+
//| محاسبه حداقل فاصله مجاز برای حد ضرر/سود به پیپ                 |
//+------------------------------------------------------------------+
int GetMinStopDistanceInPips() {
   long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stop_level == 0) return 0;
   double pip_value = GetPipValue();
   int min_pips = (int)MathCeil(stop_level * _Point / pip_value);
   return min_pips;
}

//+------------------------------------------------------------------+
//| دریافت بهترین نوع پر کردن سفارش                                 |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetOrderFillingMode() {
   int filling_mode = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling_mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
      return ORDER_FILLING_IOC;
   }
   if((filling_mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) {
      return ORDER_FILLING_FOK;
   }
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| توابع دریافت داده (چند تایم‌فریم)                              |
//+------------------------------------------------------------------+
double iClose(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, tf, shift, 1, close) > 0)
      return close[0];
   return 0;
}

double iOpen(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
   double open[];
   ArraySetAsSeries(open, true);
   if(CopyOpen(_Symbol, tf, shift, 1, open) > 0)
      return open[0];
   return 0;
}

double iHigh(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
   double high[];
   ArraySetAsSeries(high, true);
   if(CopyHigh(_Symbol, tf, shift, 1, high) > 0)
      return high[0];
   return 0;
}

double iLow(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
   double low[];
   ArraySetAsSeries(low, true);
   if(CopyLow(_Symbol, tf, shift, 1, low) > 0)
      return low[0];
   return 0;
}

double iEMA(int shift, ENUM_TIMEFRAMES tf, int period = 20) {
   double ema[];
   ArraySetAsSeries(ema, true);
   int handle = INVALID_HANDLE;
   
   if(period == 20) {
      handle = (tf == PERIOD_H1) ? ema_handle_h1 : 
               (tf == PERIOD_M15) ? ema_handle_m15 : 
               (tf == PERIOD_M5) ? ema_handle_m5 : ema_handle;
   } else if(period == 50) {
      handle = (tf == PERIOD_H1) ? ema_50_handle_h1 : 
               (tf == PERIOD_M15) ? ema_50_handle_m15 : 
               (tf == PERIOD_M5) ? ema_50_handle_m5 : ema_50_handle;
   }
   
   if(handle != INVALID_HANDLE && CopyBuffer(handle, 0, shift, 1, ema) > 0)
      return ema[0];
   return 0;
}

double iRSI(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
   double rsi[];
   ArraySetAsSeries(rsi, true);
   int handle = (tf == PERIOD_H1) ? rsi_handle_h1 : 
                (tf == PERIOD_M15) ? rsi_handle_m15 : 
                (tf == PERIOD_M5) ? rsi_handle_m5 : rsi_handle;
   
   if(handle != INVALID_HANDLE && CopyBuffer(handle, 0, shift, 1, rsi) > 0)
      return rsi[0];
   return 50;
}

double iATR(int shift) {
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atr_handle, 0, shift, 1, atr) > 0)
      return atr[0];
   return 0;
}

datetime iTimeFunc(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
   datetime time[];
   ArraySetAsSeries(time, true);
   if(CopyTime(_Symbol, tf, shift, 1, time) > 0)
      return time[0];
   return 0;
}

//+------------------------------------------------------------------+
//| تشخیص کندل دوجی                                                 |
//+------------------------------------------------------------------+
bool IsDojiCandle(int shift, ENUM_TIMEFRAMES tf, double &level, bool for_buy) {
   double open = iOpen(shift, tf);
   double close = iClose(shift, tf);
   double high = iHigh(shift, tf);
   double low = iLow(shift, tf);
   
   double body = MathAbs(close - open);
   double range = high - low;
   
   if(range > 0 && body < range * 0.2) {
      if(for_buy) level = low;
      else level = high;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| محاسبه حجم معامله - اصلاح شده برای لات 0.05 و حداقل 0.01       |
//+------------------------------------------------------------------+
double CalculateLotSize() {
   double lot = InitialLotSize; // 0.05
  
   if(Use_Money_Management) {
       // محاسبه حجم بر اساس ضریب
       lot = InitialLotSize * mm_state.current_multiplier;
      
       // دریافت محدودیت‌های بروکر
       double min_lot_broker = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
       double max_lot_broker = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
       double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
       // ================================================
       // اعمال حداقل حجم مطلق (0.01) - مهمترین بخش
       // ================================================
       double min_lot_allowed = MathMax(min_lot_broker, Min_Lot_Absolute);
      
       // راند کردن به نزدیکترین مضرب lot_step
       lot = MathRound(lot / lot_step) * lot_step;
      
       // اعمال محدودیت‌ها
       lot = MathMax(lot, min_lot_allowed);  // حداقل 0.01
       lot = MathMin(lot, max_lot_broker);   // حداکثر بروکر
      
       // فرمت کردن به رقم اعشار مناسب
       int digits = 2;
       if(lot_step >= 0.1) digits = 1;
       else if(lot_step >= 0.01) digits = 2;
       else if(lot_step >= 0.001) digits = 3;
      
       lot = NormalizeDouble(lot, digits);
      
       // ذخیره ضریب واقعی
       mm_state.real_multiplier = lot / InitialLotSize;
      
       // به‌روزرسانی آمار حجم
       if(lot > mm_state.max_lot_used) mm_state.max_lot_used = lot;
       if(mm_state.min_lot_used == 0 || lot < mm_state.min_lot_used) {
           mm_state.min_lot_used = lot;
       }
      
       Print("📊 حجم محاسبه شده: ", DoubleToString(lot, digits),
             " | ضریب تئوری: ", DoubleToString(mm_state.current_multiplier, 2),
             " | ضریب واقعی: ", DoubleToString(mm_state.real_multiplier, 2));
   }
  
   return lot;
}

//+------------------------------------------------------------------+
//| به‌روزرسانی وضعیت مدیریت سرمایه - اصلاح شده برای لات 0.05      |
//+------------------------------------------------------------------+
void UpdateMoneyManagement(double profit) {
   if(!Use_Money_Management) return;
   
   mm_state.total_trades++;
   mm_state.total_profit += profit;
   
   // ثبت حجم معامله قبلی
   double last_lot = 0;
   if(mm_state.total_trades > 0 && mm_state.last_trades[0].ticket > 0) {
      last_lot = mm_state.last_trades[0].lot_size;
   }
   
   if(profit > 0) {
      mm_state.win_trades++;
      mm_state.consecutive_wins++;
      mm_state.consecutive_losses = 0;
      
      // افزایش ضریب
      mm_state.current_multiplier *= Win_Multiplier;
      
      Print("💰 معامله برنده - سود: ", DoubleToString(profit, 2), 
            " | حجم قبلی: ", DoubleToString(last_lot, 2),
            " | ضریب جدید: ", DoubleToString(mm_state.current_multiplier, 2));
   } 
   else if(profit < 0) {
      mm_state.loss_trades++;
      mm_state.consecutive_losses++;
      mm_state.consecutive_wins = 0;
      mm_state.daily_loss_count++;
      mm_state.last_trade_day = TimeCurrent();
      
      // کاهش ضریب
      mm_state.current_multiplier *= Loss_Multiplier;
      
      Print("💸 معامله بازنده - زیان: ", DoubleToString(profit, 2),
            " | حجم قبلی: ", DoubleToString(last_lot, 2),
            " | ضریب جدید: ", DoubleToString(mm_state.current_multiplier, 2),
            " | باخت امروز: ", mm_state.daily_loss_count, " از ", Max_Daily_Loss);
   }
   
   // ================================================
   // اعمال محدودیت‌های ضریب
   // ================================================
   // محاسبه حداقل ضریب مجاز (بر اساس حداقل حجم 0.01)
   double min_lot_broker = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double min_allowed_lot = MathMax(min_lot_broker, Min_Lot_Absolute);
   double min_possible_multiplier = min_allowed_lot / InitialLotSize;
   
   mm_state.current_multiplier = MathMax(mm_state.current_multiplier, min_possible_multiplier);
   mm_state.current_multiplier = MathMin(mm_state.current_multiplier, Max_Lot_Multiplier);
   
   // ================================================
   // بازگشت به حجم اولیه پس از برد/باخت متوالی
   // ================================================
   if(Reset_After_Wins > 0 && mm_state.consecutive_wins >= Reset_After_Wins) {
      mm_state.current_multiplier = 1.0;
      Print("🔄 بازگشت به حجم اولیه پس از ", mm_state.consecutive_wins, " برد متوالی");
   }
   
   if(Reset_After_Losses > 0 && mm_state.consecutive_losses >= Reset_After_Losses) {
      mm_state.current_multiplier = 1.0;
      Print("🔄 بازگشت به حجم اولیه پس از ", mm_state.consecutive_losses, " باخت متوالی");
   }
   
   // محاسبه حجم بعدی
   double next_lot = CalculateLotSize();
   
   Print("📊 آمار - کل: ", mm_state.total_trades,
         " | برد: ", mm_state.win_trades,
         " | باخت: ", mm_state.loss_trades,
         " | سود خالص: $", DoubleToString(mm_state.total_profit, 2),
         " | حجم بعدی: ", DoubleToString(next_lot, 2));
}

//+------------------------------------------------------------------+
//| بررسی بسته شدن معاملات و به‌روزرسانی مدیریت سرمایه             |
//+------------------------------------------------------------------+
void CheckClosedTrades() {
   if(!Use_Money_Management) return;
   
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   
   static ulong processed_tickets[];
   static int processed_count = 0;
   
   if(processed_count == 0) {
      ArrayResize(processed_tickets, 100);
   }
   
   for(int i = 0; i < total; i++) {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      bool already_processed = false;
      for(int j = 0; j < processed_count; j++) {
         if(processed_tickets[j] == ticket) {
            already_processed = true;
            break;
         }
      }
      if(already_processed) continue;
      
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)Magic_Number) continue;
      
      ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL) continue;
      
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(profit == 0) continue;
      
      if(processed_count >= ArraySize(processed_tickets)) {
         ArrayResize(processed_tickets, processed_count + 100);
      }
      processed_tickets[processed_count] = ticket;
      processed_count++;
      
      UpdateMoneyManagement(profit);
   }
}

//+------------------------------------------------------------------+
//| محاسبه حد ضرر بر اساس کندل دوجی با حداقل 6 پیپ فاصله           |
//+------------------------------------------------------------------+
double CalculateSL_DojiBased(int position_type, datetime entry_time) {
   double sl = 0;
   bool is_buy = (position_type == POSITION_TYPE_BUY);
   
   Print("🔍 جستجوی کندل دوجی برای تعیین حد ضرر...");
   
   datetime doji_time = 0;
   double doji_level = 0;
   
   for(int i = 1; i <= 20; i++) {
      datetime candle_time = iTimeFunc(i, PERIOD_M5);
      if(candle_time >= entry_time) continue;
      
      double level = 0;
      if(IsDojiCandle(i, PERIOD_M5, level, is_buy)) {
         doji_time = candle_time;
         doji_level = level;
         Print("✅ کندل دوجی پیدا شد در: ", TimeToString(doji_time), 
               " | سطح: ", DoubleToString(doji_level, _Digits));
         break;
      }
   }
   
   if(doji_level == 0) {
      if(is_buy) {
         doji_level = iLow(1, PERIOD_M5);
      } else {
         doji_level = iHigh(1, PERIOD_M5);
      }
      Print("⚠️ کندل دوجی پیدا نشد - استفاده از آخرین کندل: ", 
            DoubleToString(doji_level, _Digits));
   }
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) {
      sl = doji_level;
   }
   else {
      if(is_buy) {
         double entry_price = tick.ask;
         double risk_distance = (entry_price - doji_level) / GetPipValue();
         
         if(risk_distance < 6.0) {
            sl = entry_price - PipsToPrice(6);
            Print("⚠️ فاصله تا دوجی (", DoubleToString(risk_distance, 1), 
                  " پیپ) کمتر از 6 پیپ - استاپ روی 6 پیپ تنظیم شد");
         } else {
            sl = doji_level;
            Print("✅ فاصله تا دوجی: ", DoubleToString(risk_distance, 1), " پیپ - استاپ روی دوجی");
         }
      }
      else {
         double entry_price = tick.bid;
         double risk_distance = (doji_level - entry_price) / GetPipValue();
         
         if(risk_distance < 6.0) {
            sl = entry_price + PipsToPrice(6);
            Print("⚠️ فاصله تا دوجی (", DoubleToString(risk_distance, 1), 
                  " پیپ) کمتر از 6 پیپ - استاپ روی 6 پیپ تنظیم شد");
         } else {
            sl = doji_level;
            Print("✅ فاصله تا دوجی: ", DoubleToString(risk_distance, 1), " پیپ - استاپ روی دوجی");
         }
      }
   }
   
   return NormalizeDouble(sl, _Digits);
}

//+------------------------------------------------------------------+
//| محاسبه حد سود بر اساس ریسک به ریوارد 1:3                       |
//+------------------------------------------------------------------+
double CalculateTP_RiskReward(int position_type, double entry_price, double sl_price) {
   double tp = 0;
   
   double risk_distance = MathAbs(entry_price - sl_price);
   double reward_distance = risk_distance * 3.0;
   
   if(position_type == POSITION_TYPE_BUY) {
      tp = entry_price + reward_distance;
   }
   else if(position_type == POSITION_TYPE_SELL) {
      tp = entry_price - reward_distance;
   }
   
   Print("📐 ریسک: ", DoubleToString(risk_distance / GetPipValue(), 1), " پیپ");
   Print("🎯 ریوارد (1:3): ", DoubleToString(reward_distance / GetPipValue(), 1), " پیپ");
   
   return NormalizeDouble(tp, _Digits);
}

//+------------------------------------------------------------------+
//| بررسی 3 کندل متوالی همجهت                                      |
//+------------------------------------------------------------------+
bool CheckThreeConsecutiveCandles(bool is_buy, ENUM_TIMEFRAMES tf) {
   int consecutive = 0;
   
   for(int i = 1; i <= 5; i++) {
      double close = iClose(i, tf);
      double open = iOpen(i, tf);
      
      if(is_buy) {
         if(close > open) {
            consecutive++;
            if(consecutive >= 3) return true;
         } else {
            consecutive = 0;
         }
      } else {
         if(close < open) {
            consecutive++;
            if(consecutive >= 3) return true;
         } else {
            consecutive = 0;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| بررسی فاصله قیمت از نقطه ورود (حداقل 6 پیپ)                    |
//+------------------------------------------------------------------+
bool CheckPriceDistanceFromEntry(ulong ticket, double &distance_pips) {
   if(!PositionSelectByTicket(ticket)) return false;
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   int position_type = (int)PositionGetInteger(POSITION_TYPE);
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   
   if(position_type == POSITION_TYPE_BUY) {
      distance_pips = (tick.bid - openPrice) / GetPipValue();
   } else {
      distance_pips = (openPrice - tick.ask) / GetPipValue();
   }
   
   return (distance_pips >= 6.0);
}

//+------------------------------------------------------------------+
//| انتقال استاپ به نقطه ورود بعد از 3 کندل همجهت و 6 پیپ سود      |
//+------------------------------------------------------------------+
void MoveStopLossToBreakEven(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return;
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   int position_type = (int)PositionGetInteger(POSITION_TYPE);
   bool is_buy = (position_type == POSITION_TYPE_BUY);
   
   if(!CheckThreeConsecutiveCandles(is_buy, PERIOD_M5)) {
      return;
   }
   
   Print("✅ 3 کندل متوالی همجهت در M5 تایید شد");
   
   double distance_pips = 0;
   if(!CheckPriceDistanceFromEntry(ticket, distance_pips)) {
      return;
   }
   
   if(distance_pips < 6.0) {
      Print("⏳ فاصله از نقطه ورود: ", DoubleToString(distance_pips, 1), 
            " پیپ - منتظر 6 پیپ");
      return;
   }
   
   Print("💰 فاصله از نقطه ورود: ", DoubleToString(distance_pips, 1), " پیپ");
   
   bool should_move = false;
   
   if(is_buy) {
      if(currentSL < openPrice - PipsToPrice(1)) {
         should_move = true;
      }
   } else {
      if(currentSL > openPrice + PipsToPrice(1)) {
         should_move = true;
      }
   }
   
   if(should_move) {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_SLTP;
      request.symbol = _Symbol;
      request.position = ticket;
      request.sl = openPrice;
      request.tp = currentTP;
      
      ResetLastError();
      if(OrderSend(request, result)) {
         Print("🎯 استاپ به نقطه ورود منتقل شد (سود ", 
               DoubleToString(distance_pips, 1), " پیپ)");
         Print("💵 معامله بدون ریسک شد");
         
         for(int i = 0; i < ArraySize(trail_states); i++) {
            if(trail_states[i].ticket == ticket) {
               trail_states[i].trail_stage = 1;
               trail_states[i].current_sl = openPrice;
               break;
            }
         }
      }
      else {
         Print("❌ خطا در انتقال استاپ به نقطه ورود: ", GetLastError());
      }
   }
}
//+------------------------------------------------------------------+
//| مدیریت تریل استاپ پلکانی 1:1.3 + 3 کندل M5                     |
//+------------------------------------------------------------------+
void ManageTrailStop_Advanced(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return;
   
   int state_index = -1;
   for(int i = 0; i < ArraySize(trail_states); i++) {
      if(trail_states[i].ticket == ticket) {
         state_index = i;
         break;
      }
   }
   
   if(state_index == -1) {
      int new_size = ArraySize(trail_states) + 1;
      ArrayResize(trail_states, new_size);
      state_index = new_size - 1;
      
      trail_states[state_index].ticket = ticket;
      trail_states[state_index].entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      trail_states[state_index].current_sl = PositionGetDouble(POSITION_SL);
      trail_states[state_index].trail_stage = 0;
      trail_states[state_index].is_active = true;
      trail_states[state_index].last_target_price = 0;
   }
   
   double openPrice = trail_states[state_index].entry_price;
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   int position_type = (int)PositionGetInteger(POSITION_TYPE);
   bool is_buy = (position_type == POSITION_TYPE_BUY);
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   double risk_distance = MathAbs(openPrice - currentSL);
   double profit_target = risk_distance * 1.3;
   double current_profit = 0;
   
   if(is_buy) {
      current_profit = tick.bid - openPrice;
   } else {
      current_profit = openPrice - tick.ask;
   }
   
   double current_profit_pips = current_profit / GetPipValue();
   double target_pips = profit_target / GetPipValue();
   
   // اگر هنوز به سود 1:1.3 نرسیده‌ایم
   if(current_profit < profit_target) {
      if(current_profit > 0) {
         Print("📈 سود فعلی: ", DoubleToString(current_profit_pips, 1), 
               " پیپ از هدف ", DoubleToString(target_pips, 1), " پیپ (1:1.3)");
      }
      return;
   }
   
   // مرحله 1: رسیدن به سود 1:1.3
   if(trail_states[state_index].trail_stage == 0) {
      Print("🎯 مرحله 1: سود 1:1.3 رسیده است (", DoubleToString(current_profit_pips, 1), " پیپ)");
      
      // ذخیره نقطه 1:1.3
      if(is_buy) {
         trail_states[state_index].last_target_price = openPrice + profit_target;
      } else {
         trail_states[state_index].last_target_price = openPrice - profit_target;
      }
      
      trail_states[state_index].trail_stage = 1;
      Print("💰 نقطه 1:1.3 ذخیره شد: ", DoubleToString(trail_states[state_index].last_target_price, _Digits));
   }
   
   // مرحله 2: منتظر 3 کندل متوالی در جهت روند
   if(trail_states[state_index].trail_stage == 1) {
      Print("⏳ مرحله 2: در انتظار 3 کندل متوالی در جهت روند...");
      
      if(CheckThreeConsecutiveCandles(is_buy, PERIOD_M5)) {
         Print("✅ 3 کندل متوالی همجهت در M5 تایید شد");
         
         // بررسی فاصله از نقطه ورود (حداقل 6 پیپ)
         double distance_pips = 0;
         if(!CheckPriceDistanceFromEntry(ticket, distance_pips)) {
            Print("⏳ در انتظار 6 پیپ فاصله از نقطه ورود...");
            return;
         }
         
         if(distance_pips < 6.0) {
            Print("⏳ فاصله از نقطه ورود: ", DoubleToString(distance_pips, 1), 
                  " پیپ - منتظر 6 پیپ");
            return;
         }
         
         // انتقال استاپ به نقطه 1:1.3
         double new_sl = trail_states[state_index].last_target_price;
         
         // بررسی بهتر بودن سطح جدید
         bool is_better_sl = false;
         if(is_buy) {
            if(new_sl > currentSL) {
               is_better_sl = true;
            }
         } else {
            if(new_sl < currentSL) {
               is_better_sl = true;
            }
         }
         
         if(!is_better_sl) {
            Print("⚠️ سطح 1:1.3 بهتر از استاپ فعلی نیست");
            return;
         }
         
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_SLTP;
         request.symbol = _Symbol;
         request.position = ticket;
         request.sl = new_sl;
         request.tp = currentTP;
         
         ResetLastError();
         if(OrderSend(request, result)) {
            Print("🎯 استاپ به نقطه 1:1.3 منتقل شد: ", 
                  DoubleToString(new_sl, _Digits));
            
            double locked_profit = 0;
            if(is_buy) {
               locked_profit = (new_sl - openPrice) / GetPipValue();
            } else {
               locked_profit = (openPrice - new_sl) / GetPipValue();
            }
            
            Print("💵 سود قفل شده: ", DoubleToString(locked_profit, 1), " پیپ");
            Print("📈 مرحله بعدی: منتظر سود 1:1.3 بعدی");
            
            trail_states[state_index].trail_stage = 2; // آماده برای مرحله بعدی
            trail_states[state_index].current_sl = new_sl;
         } else {
            Print("❌ خطا در انتقال استاپ: ", GetLastError());
         }
      }
   }
   
   // مراحل بعدی: ادامه تریل با الگوی مشابه
   if(trail_states[state_index].trail_stage >= 2) {
      // محاسبه ریسک جدید و هدف جدید
      double new_risk = MathAbs(trail_states[state_index].current_sl - openPrice);
      double new_target = new_risk * 1.3;
      
      if(is_buy) {
         new_target = openPrice + new_target;
      } else {
         new_target = openPrice - new_target;
      }
      
      // اگر به سود 1:1.3 جدید رسیدیم
      if((is_buy && tick.bid >= new_target) || (!is_buy && tick.ask <= new_target)) {
         Print("🎯 مرحله بعدی: سود 1:1.3 جدید رسیده است");
         
         // ذخیره نقطه جدید
         trail_states[state_index].last_target_price = new_target;
         
         // بررسی 3 کندل متوالی
         if(CheckThreeConsecutiveCandles(is_buy, PERIOD_M5)) {
            Print("✅ 3 کندل متوالی همجهت در M5 تایید شد");
            
            double new_sl = new_target;
            
            // بررسی بهتر بودن سطح جدید
            bool is_better_sl = false;
            if(is_buy) {
               if(new_sl > currentSL) {
                  is_better_sl = true;
               }
            } else {
               if(new_sl < currentSL) {
                  is_better_sl = true;
               }
            }
            
            if(is_better_sl) {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_SLTP;
               request.symbol = _Symbol;
               request.position = ticket;
               request.sl = new_sl;
               request.tp = currentTP;
               
               ResetLastError();
               if(OrderSend(request, result)) {
                  Print("🎯 استاپ به نقطه 1:1.3 جدید منتقل شد: ", 
                        DoubleToString(new_sl, _Digits));
                  
                  double locked_profit = 0;
                  if(is_buy) {
                     locked_profit = (new_sl - openPrice) / GetPipValue();
                  } else {
                     locked_profit = (openPrice - new_sl) / GetPipValue();
                  }
                  
                  Print("💵 سود قفل شده: ", DoubleToString(locked_profit, 1), " پیپ");
                  
                  trail_states[state_index].trail_stage++;
                  trail_states[state_index].current_sl = new_sl;
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| بررسی شروع روز جدید و ریست شمارنده باخت روزانه                 |
//+------------------------------------------------------------------+
void CheckNewDay() {
   if(!Reset_Daily_Loss) return;
   
   datetime current_time = TimeCurrent();
   MqlDateTime current_day, last_day;
   
   TimeToStruct(current_time, current_day);
   TimeToStruct(mm_state.last_trade_day, last_day);
   
   if(current_day.day != last_day.day || 
      current_day.mon != last_day.mon || 
      current_day.year != last_day.year) {
      
      int old_loss_count = mm_state.daily_loss_count;
      mm_state.daily_loss_count = 0;
      mm_state.last_trade_day = current_time;
      
      Print("══════════════════════════════════════════════");
      Print("🌅 شروع روز جدید معاملاتی");
      Print("📊 ریست شمارنده باخت روزانه: ", old_loss_count, " -> 0");
      Print("══════════════════════════════════════════════");
   }
}

//+------------------------------------------------------------------+
//| بررسی محدودیت باخت روزانه                                       |
//+------------------------------------------------------------------+
bool IsDailyLossLimitReached() {
   CheckNewDay();
   
   if(mm_state.daily_loss_count >= Max_Daily_Loss) {
      Print("⛔ محدودیت باخت روزانه: ", mm_state.daily_loss_count, 
            " از ", Max_Daily_Loss, " - توقف معاملات");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| نمایش آمار مدیریت سرمایه - اصلاح شده                           |
//+------------------------------------------------------------------+
void DisplayMoneyManagementStats() {
   Print("══════════════════════════════════════════════");
   Print("          آمار مدیریت سرمایه");
   Print("══════════════════════════════════════════════");
   Print("💵 سود/زیان کل: $", DoubleToString(mm_state.total_profit, 2));
   Print("📊 تعداد کل معاملات: ", mm_state.total_trades);
   
   double win_rate = mm_state.total_trades > 0 ? 
                     (double)mm_state.win_trades / mm_state.total_trades * 100 : 0;
   Print("✅ معاملات برنده: ", mm_state.win_trades, 
         " (", DoubleToString(win_rate, 1), "%)");
   Print("❌ معاملات بازنده: ", mm_state.loss_trades);
   Print("📈 برد متوالی: ", mm_state.consecutive_wins);
   Print("📉 باخت متوالی: ", mm_state.consecutive_losses);
   Print("🎯 ضریب فعلی: ", DoubleToString(mm_state.current_multiplier, 2));
   Print("📊 حجم اولیه: ", DoubleToString(InitialLotSize, 2), " لات");
   Print("🔝 بیشترین حجم: ", DoubleToString(mm_state.max_lot_used, 2), " لات");
   Print("🔻 کمترین حجم: ", DoubleToString(mm_state.min_lot_used, 2), " لات");
   Print("📅 باخت امروز: ", mm_state.daily_loss_count, " از ", Max_Daily_Loss);
   Print("══════════════════════════════════════════════");
   
   // محاسبه سود به دلار (تقریبی)
   double profit_usd = mm_state.total_profit;
   Print("💰 سود/زیان واقعی: $", DoubleToString(profit_usd, 2));
}

//+------------------------------------------------------------------+
//| بازنشانی وضعیت مدیریت سرمایه                                   |
//+------------------------------------------------------------------+
void ResetMoneyManagement() {
   ZeroMemory(mm_state);
   mm_state.current_multiplier = 1.0;
   mm_state.real_multiplier = 1.0;
   mm_state.last_trade_day = TimeCurrent();
   mm_state.min_lot_used = 0;
   mm_state.max_lot_used = 0;
   mm_state.total_trades = 0;
   mm_state.win_trades = 0;
   mm_state.loss_trades = 0;
   mm_state.total_profit = 0.0;
   
   Print("🔄 مدیریت سرمایه بازنشانی شد");
   Print("📊 حجم اولیه: ", DoubleToString(InitialLotSize, 2), " لات");
   Print("📉 حداقل حجم مجاز: ", DoubleToString(Min_Lot_Absolute, 2), " لات");
   
   ArrayFree(trail_states);
}

//+------------------------------------------------------------------+
//| تشخیص خودکار محدودیت‌های بروکر - نسخه نهایی                    |
//+------------------------------------------------------------------+
void AutoConfigureMoneyManagement() {
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   Print("══════════════════════════════════════════════");
   Print("📊 تشخیص خودکار محدودیت‌های بروکر:");
   Print("   • حداقل حجم: ", DoubleToString(min_lot, 3));
   Print("   • حداکثر حجم: ", DoubleToString(max_lot, 1));
   Print("   • گام حجم: ", DoubleToString(lot_step, 3));
   Print("══════════════════════════════════════════════");
   
   // ================================================
   // بررسی و هشدار - بدون تغییر مقدار
   // ================================================
   bool config_error = false;
   
   if(InitialLotSize < min_lot) {
      Print("❌ خطای بحرانی: حجم اولیه (", DoubleToString(InitialLotSize, 2), 
            ") کمتر از حداقل بروکر (", DoubleToString(min_lot, 2), ") است!");
      Print("   📝 لطفاً InitialLotSize را به ", DoubleToString(min_lot, 2), " تغییر دهید");
      config_error = true;
   }
   
   if(Min_Lot_Absolute < min_lot) {
      Print("⚠️ هشدار: حداقل حجم مطلق (", DoubleToString(Min_Lot_Absolute, 2), 
            ") کمتر از حداقل بروکر (", DoubleToString(min_lot, 2), ") است!");
      Print("   📝 توصیه: Min_Lot_Absolute را به ", DoubleToString(min_lot, 2), " افزایش دهید");
   }
   
   double remainder = MathAbs(MathMod(InitialLotSize, lot_step));
   if(remainder > 0.0001) {
      double nearest_lot = MathRound(InitialLotSize / lot_step) * lot_step;
      nearest_lot = MathMax(nearest_lot, min_lot);
      
      Print("⚠️ هشدار: حجم اولیه (", DoubleToString(InitialLotSize, 3), 
            ") مضربی از گام حجم (", DoubleToString(lot_step, 3), ") نیست!");
      Print("   📝 نزدیکترین حجم مجاز: ", DoubleToString(nearest_lot, 3));
   }
   
   // ================================================
   // محاسبه حداقل ضریب ممکن
   // ================================================
   double min_allowed_lot = MathMax(min_lot, Min_Lot_Absolute);
   double min_possible_multiplier = min_allowed_lot / InitialLotSize;
   
   Print("📊 تحلیل مدیریت سرمایه:");
   Print("   • حداقل حجم قابل معامله: ", DoubleToString(min_allowed_lot, 3), " لات");
   Print("   • حداقل ضریب ممکن: ", DoubleToString(min_possible_multiplier, 3));
   Print("   • حداکثر ضریب تنظیم شده: ", DoubleToString(Max_Lot_Multiplier, 1));
   
   // ================================================
   // پیشنهاد تنظیمات بهینه
   // ================================================
   if(!config_error) {
      Print("📝 تنظیمات پیشنهادی برای این بروکر:");
      Print("   • حجم اولیه: ", DoubleToString(InitialLotSize, 2), " لات ✅");
      
      if(Win_Multiplier * InitialLotSize < min_allowed_lot + lot_step) {
         double recommended_win = (min_allowed_lot + lot_step) / InitialLotSize;
         Print("   • ضریب برد: ", DoubleToString(Win_Multiplier, 2), 
               " ⚠️ (پیشنهاد: ", DoubleToString(recommended_win, 2), ")");
      } else {
         Print("   • ضریب برد: ", DoubleToString(Win_Multiplier, 2), " ✅");
      }
      
      if(Loss_Multiplier * InitialLotSize < min_allowed_lot) {
         double recommended_loss = min_allowed_lot / InitialLotSize;
         Print("   • ضریب باخت: ", DoubleToString(Loss_Multiplier, 2), 
               " ⚠️ (پیشنهاد: ", DoubleToString(recommended_loss, 2), ")");
      } else {
         Print("   • ضریب باخت: ", DoubleToString(Loss_Multiplier, 2), " ✅");
      }
   }
   
   Print("══════════════════════════════════════════════");
}
//+------------------------------------------------------------------+
//| تشخیص سشن معاملاتی فعال - لندن و نیویورک                       |
//+------------------------------------------------------------------+
bool IsTradingSessionActive() {
   MqlDateTime current_time;
   TimeToStruct(TimeCurrent(), current_time);
   
   if(current_time.day_of_week == 0) {
      Print("⏸️ یکشنبه - بازار بسته است");
      return false;
   }
   
   if(current_time.day_of_week == 6) {
      Print("⏸️ شنبه - بازار بسته است");
      return false;
   }
   
   if(current_time.day_of_week == 5) {
      if(Avoid_Friday_Close && current_time.hour >= Friday_Close_Hour) {
         Print("⏸️ جمعه - پایان هفته معاملاتی، ورود ممنوع");
         return false;
      }
   }
   
   bool london_active = Use_London_Session && 
                        current_time.hour >= London_Start_Hour && 
                        current_time.hour < London_End_Hour;
   
   bool ny_active = Use_NY_Session && 
                    current_time.hour >= NY_Start_Hour && 
                    current_time.hour < NY_End_Hour;
   
   bool overlap_active = Use_Overlap_Session && 
                         current_time.hour >= NY_Start_Hour && 
                         current_time.hour < London_End_Hour;
   
   return (london_active || ny_active || overlap_active);
}

//+------------------------------------------------------------------+
//| تشخیص خط روند                                                   |
//+------------------------------------------------------------------+
TrendLine DetectTrendLine(bool uptrend, int bars = 20) {
   TrendLine line = {};
   line.isValid = false;
   
   double highs[], lows[];
   datetime times[];
   
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(times, true);
   
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, highs) <= 0) return line;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, lows) <= 0) return line;
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, bars, times) <= 0) return line;
   
   if(uptrend) {
      int pivot1 = -1, pivot2 = -1;
      for(int i = 2; i < bars - 2; i++) {
         if(lows[i] < lows[i-1] && lows[i] < lows[i-2] && 
            lows[i] < lows[i+1] && lows[i] < lows[i+2]) {
            if(pivot1 == -1) pivot1 = i;
            else if(pivot2 == -1 && i > pivot1 + 3) {
               pivot2 = i;
               break;
            }
         }
      }
      
      if(pivot1 != -1 && pivot2 != -1 && pivot1 != pivot2) {
         line.point1_price = lows[pivot1];
         line.point2_price = lows[pivot2];
         line.point1_time = times[pivot1];
         line.point2_time = times[pivot2];
         line.slope = (line.point2_price - line.point1_price) / (pivot1 - pivot2);
         line.isValid = true;
      }
   }
   else {
      int pivot1 = -1, pivot2 = -1;
      for(int i = 2; i < bars - 2; i++) {
         if(highs[i] > highs[i-1] && highs[i] > highs[i-2] && 
            highs[i] > highs[i+1] && highs[i] > highs[i+2]) {
            if(pivot1 == -1) pivot1 = i;
            else if(pivot2 == -1 && i > pivot1 + 3) {
               pivot2 = i;
               break;
            }
         }
      }
      
      if(pivot1 != -1 && pivot2 != -1 && pivot1 != pivot2) {
         line.point1_price = highs[pivot1];
         line.point2_price = highs[pivot2];
         line.point1_time = times[pivot1];
         line.point2_time = times[pivot2];
         line.slope = (line.point2_price - line.point1_price) / (pivot1 - pivot2);
         line.isValid = true;
      }
   }
   
   return line;
}

//+------------------------------------------------------------------+
//| تشخیص شکست خط روند                                              |
//+------------------------------------------------------------------+
bool IsTrendLineBreak(bool& breakDirection) {
   TrendLine upLine = DetectTrendLine(true, 30);
   TrendLine downLine = DetectTrendLine(false, 30);
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   
   if(upLine.isValid) {
      double currentPrice = tick.bid;
      double time_diff = (double)(TimeCurrent() - upLine.point1_time) / 60;
      double lineValueAtCurrent = upLine.point1_price + upLine.slope * time_diff;
      
      if(currentPrice < lineValueAtCurrent && iClose(1) < lineValueAtCurrent) {
         breakDirection = false;
         return true;
      }
   }
   
   if(downLine.isValid) {
      double currentPrice = tick.ask;
      double time_diff = (double)(TimeCurrent() - downLine.point1_time) / 60;
      double lineValueAtCurrent = downLine.point1_price + downLine.slope * time_diff;
      
      if(currentPrice > lineValueAtCurrent && iClose(1) > lineValueAtCurrent) {
         breakDirection = true;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| تشخیص سایکل بازار                                               |
//+------------------------------------------------------------------+
CycleInfo DetectMarketCycle(ENUM_TIMEFRAMES tf) {
   CycleInfo info = {};
   info.isValid = false;
   
   double atr_curr = iATR(1);
   if(atr_curr == 0) return info;
   
   double avg_candle_size = 0;
   for(int i = 1; i <= 14; i++) {
      avg_candle_size += MathAbs(iHigh(i, tf) - iLow(i, tf));
   }
   avg_candle_size /= 14;
   
   double ema_20_1 = iEMA(1, tf, 20);
   double ema_20_2 = iEMA(2, tf, 20);
   double ema_50_1 = iEMA(1, tf, 50);
   
   bool isTrendUp = (ema_20_1 > ema_20_2 && ema_20_1 > ema_50_1);
   bool isTrendDown = (ema_20_1 < ema_20_2 && ema_20_1 < ema_50_1);
   
   double highest = iHigh(1, tf);
   double lowest = iLow(1, tf);
   datetime highest_time = iTimeFunc(1, tf);
   datetime lowest_time = iTimeFunc(1, tf);
   
   for(int i = 2; i <= 20; i++) {
      double high = iHigh(i, tf);
      double low = iLow(i, tf);
      if(high > highest) {
         highest = high;
         highest_time = iTimeFunc(i, tf);
      }
      if(low < lowest) {
         lowest = low;
         lowest_time = iTimeFunc(i, tf);
      }
   }
   
   double range = highest - lowest;
   info.upper_level = highest;
   info.lower_level = lowest;
   
   double normalized_candle = avg_candle_size / GetPipValue();
   double normalized_range = range / GetPipValue();
   double normalized_atr = atr_curr / GetPipValue();
   
   if(normalized_candle > normalized_atr * 1.5) {
      info.cycle = CYCLE_BREAKOUT;
      info.direction = (iClose(1, tf) > iOpen(1, tf)) ? "up" : "down";
      info.isValid = true;
   }
   else if(normalized_range < normalized_atr * 0.8) {
      info.cycle = CYCLE_NARROW_CHANNEL;
      info.direction = isTrendUp ? "up" : (isTrendDown ? "down" : "neutral");
      info.isValid = true;
   }
   else if(normalized_range > normalized_atr * 1.2 && (isTrendUp || isTrendDown)) {
      info.cycle = CYCLE_WIDE_CHANNEL;
      info.direction = isTrendUp ? "up" : "down";
      info.isValid = true;
   }
   else {
      info.cycle = CYCLE_TRADING_RANGE;
      info.direction = "neutral";
      info.isValid = true;
   }
   
   return info;
}

//+------------------------------------------------------------------+
//| تشخیص واگرایی RSI                                               |
//+------------------------------------------------------------------+
DivergenceInfo DetectRSIDivergence(ENUM_TIMEFRAMES tf) {
   DivergenceInfo div = {};
   
   double prices_low[MAX_PIVOTS];
   double rsi_low[MAX_PIVOTS];
   double prices_high[MAX_PIVOTS];
   double rsi_high[MAX_PIVOTS];
   
   ArrayInitialize(prices_low, 0);
   ArrayInitialize(rsi_low, 0);
   ArrayInitialize(prices_high, 0);
   ArrayInitialize(rsi_high, 0);
   
   int low_pivot_count = 0;
   for(int i = 2; i < 30; i++) {
      if(iLow(i, tf) < iLow(i-1, tf) && iLow(i, tf) < iLow(i+1, tf)) {
         if(low_pivot_count < MAX_PIVOTS) {
            prices_low[low_pivot_count] = iLow(i, tf);
            rsi_low[low_pivot_count] = iRSI(i, tf);
            low_pivot_count++;
         }
      }
   }
   
   int high_pivot_count = 0;
   for(int i = 2; i < 30; i++) {
      if(iHigh(i, tf) > iHigh(i-1, tf) && iHigh(i, tf) > iHigh(i+1, tf)) {
         if(high_pivot_count < MAX_PIVOTS) {
            prices_high[high_pivot_count] = iHigh(i, tf);
            rsi_high[high_pivot_count] = iRSI(i, tf);
            high_pivot_count++;
         }
      }
   }
   
   if(low_pivot_count >= 2) {
      if(prices_low[0] < prices_low[1] && rsi_low[0] > rsi_low[1]) {
         div.regular_bullish = true;
      }
   }
   
   if(high_pivot_count >= 2) {
      if(prices_high[0] > prices_high[1] && rsi_high[0] < rsi_high[1]) {
         div.regular_bearish = true;
      }
   }
   
   return div;
}

//+------------------------------------------------------------------+
//| نمایش سایکل‌های بازار                                           |
//+------------------------------------------------------------------+
void DisplayMarketCycles() {
   CycleInfo cycle_h1 = DetectMarketCycle(PERIOD_H1);
   CycleInfo cycle_m15 = DetectMarketCycle(PERIOD_M15);
   CycleInfo cycle_m5 = DetectMarketCycle(PERIOD_M5);
   
   string cycle_names[4] = {"BREAKOUT", "NARROW CHANNEL", "WIDE CHANNEL", "TRADING RANGE"};
   
   Print("══════════════════════════════════════════════");
   Print("          تشخیص سایکل‌های بازار");
   Print("══════════════════════════════════════════════");
   
   if(cycle_h1.isValid) {
      Print("H1  - سایکل: ", cycle_names[cycle_h1.cycle], 
            " | جهت: ", cycle_h1.direction);
   }
   if(cycle_m15.isValid) {
      Print("M15 - سایکل: ", cycle_names[cycle_m15.cycle], 
            " | جهت: ", cycle_m15.direction);
   }
   if(cycle_m5.isValid) {
      Print("M5  - سایکل: ", cycle_names[cycle_m5.cycle], 
            " | جهت: ", cycle_m5.direction);
   }
   Print("══════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| تابع اصلی برای تصمیم‌گیری معاملاتی                             |
//+------------------------------------------------------------------+
bool ShouldEnterTrade(bool& isBuy) {
   if(IsDailyLossLimitReached()) return false;
   if(!IsTradingSessionActive()) return false;
   
   CycleInfo cycle_h1 = DetectMarketCycle(PERIOD_H1);
   CycleInfo cycle_m15 = DetectMarketCycle(PERIOD_M15);
   
   if(!cycle_h1.isValid || !cycle_m15.isValid) return false;
   
   bool breakDirection;
   if(!IsTrendLineBreak(breakDirection)) return false;
   
   DivergenceInfo div = DetectRSIDivergence(PERIOD_M5);
   
   if(breakDirection) {
      if(cycle_h1.direction != "down" && cycle_m15.direction != "down") {
         if(div.regular_bullish) {
            isBuy = true;
            Print("✅ سیگنال خرید - شکست روند + واگرایی صعودی");
            return true;
         }
      }
   }
   else {
      if(cycle_h1.direction != "up" && cycle_m15.direction != "up") {
         if(div.regular_bearish) {
            isBuy = false;
            Print("✅ سیگنال فروش - شکست روند + واگرایی نزولی");
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| بررسی شرایط معاملاتی                                            |
//+------------------------------------------------------------------+
bool IsTradingAllowed() {
   if(IsDailyLossLimitReached()) return false;
   if(!IsTradingSessionActive()) return false;
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   
   double spread = (tick.ask - tick.bid) / GetPipValue();
   if(spread > Max_Spread_Pips) {
      Print("⚠️ اسپرد زیاد: ", DoubleToString(spread, 1), " پیپ");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| بررسی وجود پوزیشن باز                                           |
//+------------------------------------------------------------------+
bool HasPosition() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == Magic_Number) {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| باز کردن معامله با استراتژی جدید                                |
//+------------------------------------------------------------------+
void OpenTrade_Advanced(bool isBuy) {
   if(!IsTradingAllowed()) return;
   if(HasPosition()) return;
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = CalculateLotSize();
   request.deviation = Slippage_Points;
   request.magic = (long)Magic_Number;
   request.type_filling = GetOrderFillingMode();
   
   if(isBuy) {
      request.type = ORDER_TYPE_BUY;
      request.price = tick.ask;
   } else {
      request.type = ORDER_TYPE_SELL;
      request.price = tick.bid;
   }
   
   request.sl = CalculateSL_DojiBased(request.type, TimeCurrent());
   request.tp = CalculateTP_RiskReward(request.type, request.price, request.sl);
   
   Print("══════════════════════════════════════════════");
   Print("📊 شروع معامله جدید:");
   Print("💰 ورود: ", DoubleToString(request.price, _Digits));
   Print("🛑 حد ضرر: ", DoubleToString(request.sl, _Digits), 
         " (", DoubleToString(MathAbs(request.price - request.sl) / GetPipValue(), 1), " پیپ)");
   Print("🎯 حد سود: ", DoubleToString(request.tp, _Digits));
   Print("📊 حجم: ", DoubleToString(request.volume, 2), " لات");
   Print("══════════════════════════════════════════════");
   
   ResetLastError();
   if(OrderSend(request, result)) {
      if(result.retcode == TRADE_RETCODE_DONE) {
         Print("✅ معامله با موفقیت باز شد - تیکت: ", result.order);
         Print("📈 ضریب حجم فعلی: ", DoubleToString(mm_state.current_multiplier, 2));
         Print("📉 باخت امروز: ", mm_state.daily_loss_count, " از ", Max_Daily_Loss);
      } else {
         Print("❌ خطا در باز کردن معامله: ", result.retcode, " - ", result.comment);
      }
   } else {
      Print("❌ خطا در ارسال سفارش: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| ایجاد هندل‌های ایندیکاتور                                       |
//+------------------------------------------------------------------+
bool CreateIndicatorHandles() {
   ema_handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema_handle_h1 = iMA(_Symbol, PERIOD_H1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema_handle_m15 = iMA(_Symbol, PERIOD_M15, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema_handle_m5 = iMA(_Symbol, PERIOD_M5, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   ema_50_handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema_50_handle_h1 = iMA(_Symbol, PERIOD_H1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema_50_handle_m15 = iMA(_Symbol, PERIOD_M15, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema_50_handle_m5 = iMA(_Symbol, PERIOD_M5, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
   
   rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   rsi_handle_h1 = iRSI(_Symbol, PERIOD_H1, RSI_Period, PRICE_CLOSE);
   rsi_handle_m15 = iRSI(_Symbol, PERIOD_M15, RSI_Period, PRICE_CLOSE);
   rsi_handle_m5 = iRSI(_Symbol, PERIOD_M5, RSI_Period, PRICE_CLOSE);
   
   if(ema_handle == INVALID_HANDLE || ema_50_handle == INVALID_HANDLE ||
      atr_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE) {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| آزادسازی هندل‌های ایندیکاتور                                    |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles() {
   if(ema_handle != INVALID_HANDLE) IndicatorRelease(ema_handle);
   if(ema_50_handle != INVALID_HANDLE) IndicatorRelease(ema_50_handle);
   if(ema_handle_h1 != INVALID_HANDLE) IndicatorRelease(ema_handle_h1);
   if(ema_50_handle_h1 != INVALID_HANDLE) IndicatorRelease(ema_50_handle_h1);
   if(ema_handle_m15 != INVALID_HANDLE) IndicatorRelease(ema_handle_m15);
   if(ema_50_handle_m15 != INVALID_HANDLE) IndicatorRelease(ema_50_handle_m15);
   if(ema_handle_m5 != INVALID_HANDLE) IndicatorRelease(ema_handle_m5);
   if(ema_50_handle_m5 != INVALID_HANDLE) IndicatorRelease(ema_50_handle_m5);
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
   if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
   if(rsi_handle_h1 != INVALID_HANDLE) IndicatorRelease(rsi_handle_h1);
   if(rsi_handle_m15 != INVALID_HANDLE) IndicatorRelease(rsi_handle_m15);
   if(rsi_handle_m5 != INVALID_HANDLE) IndicatorRelease(rsi_handle_m5);
}

//+------------------------------------------------------------------+
//| تابع اولیه سازی                                                 |
//+------------------------------------------------------------------+
int OnInit() {
   if(!CreateIndicatorHandles()) {
      Print("❌ خطا در ایجاد ایندیکاتورها");
      return INIT_FAILED;
   }
   
   ResetMoneyManagement();
   AutoConfigureMoneyManagement();
   
   Print("══════════════════════════════════════════════");
   Print("      استراتژی آل بروکس H2/L2 - MT5");
   Print("      ⏰ فقط در سشن‌های لندن و نیویورک");
   Print("      🎯 نسخه 4.3 - مدیریت سرمایه واقعی");
   Print("══════════════════════════════════════════════");
   Print("📊 استراتژی حد ضرر:");
   Print("  • استاپ روی کندل دوجی M5");
   Print("  • حداقل فاصله 6 پیپ از قیمت ورود");
   Print("  • حد سود 1:3");
   Print("  • مرحله 1: 3 کندل M5 + 6 پیپ سود → استاپ به نقطه ورود");
   Print("  • مراحل بعدی: 1:1.3 + دوجی H1 + 3 کندل M5 + 6 پیپ فاصله");
   Print("══════════════════════════════════════════════");
   Print("📊 مدیریت سرمایه:");
   Print("  • حجم اولیه: ", DoubleToString(InitialLotSize, 2), " لات");
   Print("  • حداقل حجم مطلق: ", DoubleToString(Min_Lot_Absolute, 2), " لات");
   Print("  • ضریب برد: ", DoubleToString(Win_Multiplier, 2));
   Print("  • ضریب باخت: ", DoubleToString(Loss_Multiplier, 2));
   Print("══════════════════════════════════════════════");
   Print("🇬🇧 لندن: ", London_Start_Hour, ":00 - ", London_End_Hour, ":00");
   Print("🇺🇸 نیویورک: ", NY_Start_Hour, ":00 - ", NY_End_Hour, ":00");
   Print("══════════════════════════════════════════════");
   Print("══════════════════════════════════════════════");
   Print("📊 استراتژی حد ضرر:");
   Print("  • استاپ روی کندل دوجی M5");
   Print("  • حداقل فاصله 6 پیپ از قیمت ورود");
   Print("  • حد سود 1:3");
   Print("  • مرحله 1: 3 کندل M5 + 6 پیپ سود → استاپ به نقطه ورود");
   Print("  • مراحل بعدی: رسیدن به 1:1.3 → 3 کندل M5 همجهت → استاپ به نقطه 1:1.3");
   Print("══════════════════════════════════════════════");
   int min_stop = GetMinStopDistanceInPips();
   if(min_stop > 0) {
      Print("ℹ️ حداقل فاصله مجاز بروکر: ", min_stop, " پیپ");
   } else {
      Print("ℹ️ حساب ECN/RAW - بدون محدودیت");
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| تابع Deinit                                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ReleaseIndicatorHandles();
   
   if(Use_Money_Management) {
      Print("══════════════════════════════════════════════");
      Print("          آمار نهایی مدیریت سرمایه");
      DisplayMoneyManagementStats();
   }
   
   Print("استراتژی متوقف شد");
}

//+------------------------------------------------------------------+
//| تابع OnTick                                                    |
//+------------------------------------------------------------------+
void OnTick() {
   CheckNewDay();
   
   static datetime lastBarTimeM5 = 0;
   datetime currentTimeM5 = iTimeFunc(0, PERIOD_M5);
   
   if(currentTimeM5 == 0 || currentTimeM5 == lastBarTimeM5) return;
   lastBarTimeM5 = currentTimeM5;
   
   if(Use_Money_Management) {
      CheckClosedTrades();
   }
   
   static int barCounter = 0;
   barCounter++;
   if(barCounter >= 10) {
      DisplayMarketCycles();
      barCounter = 0;
   }
   
   static int statsCounter = 0;
   statsCounter++;
   if(Use_Money_Management && statsCounter >= 20) {
      DisplayMoneyManagementStats();
      statsCounter = 0;
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Magic_Number) continue;
      
      MoveStopLossToBreakEven(ticket);
      ManageTrailStop_Advanced(ticket);
   }
   
   bool isBuy;
   if(ShouldEnterTrade(isBuy)) {
      OpenTrade_Advanced(isBuy);
   }
}
//+------------------------------------------------------------------+