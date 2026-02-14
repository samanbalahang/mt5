//+------------------------------------------------------------------+
//|                                                   TradeRiskManager.mqh |
//|                                        مدیریت معامله، ریسک، حد ضرر و حد سود |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "2.00"

#include "EntrySignalManager.mqh"
#include "TrendCycleManager.mqh"

enum ENUM_TRADE_STATUS
{
   STATUS_NO_TRADE,
   STATUS_SIGNAL_DETECTED,
   STATUS_ENTRY_PENDING,
   STATUS_POSITION_OPEN,
   STATUS_PARTIAL_CLOSED,
   STATUS_FULLY_CLOSED,
   STATUS_STOPPED
};

enum ENUM_EXIT_REASON
{
   EXIT_TAKE_PROFIT,
   EXIT_STOP_LOSS,
   EXIT_TRAILING_STOP,
   EXIT_REVERSAL_SIGNAL,
   EXIT_MANUAL,
   EXIT_TIME_BASED
};

struct TradeSetup
{
   ENUM_SIGNAL_TYPE      signalType;
   bool                  isLong;
   double                entryPrice;
   double                stopLoss;
   double                takeProfit1;
   double                takeProfit2;
   double                positionSize;     // حجم کل
   double                initialSize;      // 20% اولیه
   double                addSize;          // 80% بعدی
   datetime              signalTime;
   int                   signalStrength;
   string                symbol;
   bool                  isValid;
};

struct PositionInfo
{
   int                   ticket;
   datetime              openTime;
   double                openPrice;
   double                currentPrice;
   double                stopLoss;
   double                takeProfit;
   double                volume;
   bool                  isLong;
   ENUM_TRADE_STATUS     status;
   double                profit;
   double                riskAmount;
};

struct RiskParameters
{
   double               maxRiskPerTrade;      // حداکثر ریسک به درصد (مثلاً 1%)
   double               maxRiskPerDay;        // حداکثر ریسک روزانه
   double               maxDrawdown;          // حداکثر ریزش مجاز
   double               minRiskReward;        // حداقل ریسک به ریوارد (1.5)
   double               maxSpread;            // حداکثر اسپرد مجاز
   bool                 useTrailingStop;      // استفاده از تریلینگ استاپ
   double               trailingActivation;   // فعالسازی تریلینگ (مثلاً 1%)
   double               trailingDistance;     // فاصله تریلینگ
   int                  maxPositions;         // حداکثر پوزیشن همزمان
   bool                 useBreakeven;         // انتقال به بریک ایون
   double               breakevenActivation;  // فاصله برای بریک ایون
};

class TradeRiskManager
{
private:
   EntrySignalManager    entryManager;
   TrendCycleManager     cycleManager;
   
   RiskParameters        riskParams;
   PositionInfo          activePositions[];
   TradeSetup            pendingTrades[];
   
   double                accountBalance;
   double                dailyPnL;
   datetime              lastResetTime;
   
   // ========== متغیرهای جدید برای مدیریت SL اجباری ==========
   bool                  lastTradeSLFailed;     // آیا آخرین معامله SL ثبت نشد؟
   double                forcedSLDistance;      // فاصله اجباری SL (6 پیپ)
   int                   consecutiveSLFailures; // تعداد دفعات متوالی عدم ثبت SL
   datetime              lastSLFailTime;        // زمان آخرین عدم ثبت SL
   double                pipValue;               // ارزش پیپ
   
public:
   TradeRiskManager()
   {
      // تنظیمات پیشفرض ریسک
      riskParams.maxRiskPerTrade = 1.0;        // 1% ریسک به ازای هر معامله
      riskParams.maxRiskPerDay = 3.0;          // 3% ریسک روزانه
      riskParams.maxDrawdown = 10.0;           // 10% حداکثر ریزش
      riskParams.minRiskReward = 1.5;          // حداقل 1.5
      riskParams.maxSpread = 2.0;              // حداکثر 2 پیپ (برای فارکس)
      riskParams.useTrailingStop = true;       // فعال
      riskParams.trailingActivation = 1.0;     // 1% سود فعال میشود
      riskParams.trailingDistance = 0.5;       // 0.5% فاصله
      riskParams.maxPositions = 3;             // حداکثر 3 پوزیشن همزمان
      riskParams.useBreakeven = true;          // فعال
      riskParams.breakevenActivation = 1.0;    // 1% سود به بریک ایون
      
      accountBalance = 0;
      dailyPnL = 0;
      lastResetTime = TimeCurrent();
      
      ArrayResize(activePositions, 0);
      ArrayResize(pendingTrades, 0);
      
      // ========== مقداردهی متغیرهای SL اجباری ==========
      lastTradeSLFailed = false;
      forcedSLDistance = 6 * GetPipValue();     // 6 پیپ
      consecutiveSLFailures = 0;
      lastSLFailTime = 0;
      pipValue = GetPipValue();
   }
   
   // ========== متدهای جدید برای مدیریت SL اجباری ==========
   
   //-------------------------------------------------------------------
   // دریافت ارزش پیپ بر اساس بروکر
   //-------------------------------------------------------------------
   double GetPipValue()
   {
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(digits == 5 || digits == 3)
         return point * 10;  // بروکر 5 رقم
      else if(digits == 4 || digits == 2)
         return point;       // بروکر 4 رقم
      else if(digits == 1)
         return point;       // یرن
      else
         return point;       // پیش‌فرض
   }
   
   //-------------------------------------------------------------------
   // ثبت عدم موفقیت SL
   //-------------------------------------------------------------------
   void RecordSLFailure()
   {
      lastTradeSLFailed = true;
      consecutiveSLFailures++;
      lastSLFailTime = TimeCurrent();
      
      Print("⚠️ ثبت SL در معامله قبلی ناموفق بود - دفعات متوالی: ", consecutiveSLFailures);
   }
   
   //-------------------------------------------------------------------
   // ثبت موفقیت SL
   //-------------------------------------------------------------------
   void RecordSLSuccess()
   {
      lastTradeSLFailed = false;
      consecutiveSLFailures = 0;
      
      Print("✅ ثبت SL با موفقیت انجام شد - شمارنده ریست شد");
   }
   
   //-------------------------------------------------------------------
   // دریافت SL اجباری (6 پیپ پایین‌تر/بالاتر)
   //-------------------------------------------------------------------
   double GetForcedStopLoss(double entryPrice, bool isLong)
   {
      if(isLong)
         return entryPrice - forcedSLDistance;  // 6 پیپ پایین‌تر
      else
         return entryPrice + forcedSLDistance;  // 6 پیپ بالاتر
   }
   
   //-------------------------------------------------------------------
   // بررسی نیاز به SL اجباری
   //-------------------------------------------------------------------
   bool NeedsForcedSL()
   {
      // اگر آخرین معامله SL ثبت نشده باشد
      if(lastTradeSLFailed)
      {
         Print("⚠️ نیاز به استفاده از SL اجباری (6 پیپ) - آخرین معامله SL ثبت نشد");
         return true;
      }
      
      // اگر در 1 ساعت گذشته 3 بار SL ثبت نشده باشد
      if(consecutiveSLFailures >= 3 && TimeCurrent() - lastSLFailTime < 3600)
      {
         Print("⚠️ هشدار: 3 بار متوالی SL ثبت نشده - استفاده از SL اجباری به مدت 1 ساعت");
         return true;
      }
      
      return false;
   }
   
   //-------------------------------------------------------------------
   // ریست وضعیت SL اجباری (برای روز جدید)
   //-------------------------------------------------------------------
   void ResetForcedSLStatus()
   {
      lastTradeSLFailed = false;
      consecutiveSLFailures = 0;
      lastSLFailTime = 0;
      Print("📅 ریست وضعیت SL اجباری - روز جدید معاملاتی");
   }
   
   //-------------------------------------------------------------------
   // تنظیم فاصله SL اجباری (بر حسب پیپ)
   //-------------------------------------------------------------------
   void SetForcedSLDistance(int pips)
   {
      forcedSLDistance = pips * GetPipValue();
      Print("📏 فاصله SL اجباری به ", pips, " پیپ تغییر یافت");
   }
   
   //-------------------------------------------------------------------
   // به‌روزرسانی موجودی حساب
   //-------------------------------------------------------------------
   void UpdateAccountBalance(double balance)
   {
      // ریست روزانه
      datetime currentTime = TimeCurrent();
      if(TimeDay(currentTime) != TimeDay(lastResetTime))
      {
         dailyPnL = 0;
         lastResetTime = currentTime;
         
         // ریست وضعیت SL اجباری در شروع روز جدید (اختیاری)
         // ResetForcedSLStatus();
      }
      
      accountBalance = balance;
   }
   
   //-------------------------------------------------------------------
   // محاسبه حجم موقعیت بر اساس ریسک
   //-------------------------------------------------------------------
   double CalculatePositionSize(double entry, double stopLoss, double riskPercent = -1)
   {
      if(accountBalance <= 0) return 0;
      
      double risk = (riskPercent > 0) ? riskPercent : riskParams.maxRiskPerTrade;
      double riskAmount = accountBalance * (risk / 100.0);
      
      // بررسی ریسک روزانه
      if(dailyPnL + riskAmount > accountBalance * (riskParams.maxRiskPerDay / 100.0))
         return 0;
      
      double stopDistance = MathAbs(entry - stopLoss);
      if(stopDistance == 0) return 0;
      
      // محاسبه حجم اولیه با احتساب ارزش تیک
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickSize == 0 || tickValue == 0) return 0;
      
      double volume = (riskAmount / (stopDistance / tickSize * tickValue));
      
      // گرد کردن به حجم مجاز
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      volume = MathRound(volume / step) * step;
      if(volume < minVol) volume = minVol;
      if(volume > maxVol) volume = maxVol;
      
      return volume;
   }
   
   //-------------------------------------------------------------------
   // تنظیمات اولیه معامله - نسخه اصلاح شده با پشتیبانی از SL اجباری
   //-------------------------------------------------------------------
   TradeSetup CreateTradeSetup(const SignalBar &signal, double fullVolume)
   {
      TradeSetup setup;
      setup.isValid = false;
      
      if(signal.type == SIGNAL_NONE) return setup;
      
      // محاسبه حجم
      double totalVolume = (fullVolume > 0) ? fullVolume : 
                           CalculatePositionSize(signal.entryPrice, signal.stopLoss);
      
      if(totalVolume <= 0) return setup;
      
      setup.signalType = signal.type;
      setup.isLong = signal.isLong;
      setup.entryPrice = signal.entryPrice;
      setup.takeProfit2 = signal.takeProfit2;
      setup.positionSize = totalVolume;
      setup.initialSize = totalVolume * 0.2;    // 20% اولیه
      setup.addSize = totalVolume * 0.8;        // 80% بعدی
      setup.signalTime = signal.time;
      setup.signalStrength = signal.strength;
      setup.symbol = _Symbol;
      
      // ========== مدیریت SL با قابلیت SL اجباری ==========
      if(NeedsForcedSL())
      {
         // استفاده از SL اجباری (6 پیپ)
         setup.stopLoss = GetForcedStopLoss(signal.entryPrice, signal.isLong);
         setup.takeProfit1 = 0;  // TP بعداً محاسبه می‌شود
         
         Print("🔒 استفاده از SL اجباری - فاصله: ", forcedSLDistance / pipValue, " پیپ");
         Print("   قیمت ورود: ", DoubleToString(setup.entryPrice, _Digits), 
               " | SL: ", DoubleToString(setup.stopLoss, _Digits));
      }
      else
      {
         // استفاده از SL معمولی از سیگنال
         setup.stopLoss = signal.stopLoss;
         setup.takeProfit1 = signal.takeProfit1;
      }
      
      // تنظیم تی‌پی اگر وجود نداشت
      if(setup.takeProfit1 == 0)
      {
         double riskReward = (signal.strength >= 4) ? 2.0 : 1.5;
         if(signal.isLong)
            setup.takeProfit1 = signal.entryPrice + 
                              (signal.entryPrice - setup.stopLoss) * riskReward;
         else
            setup.takeProfit1 = signal.entryPrice - 
                              (setup.stopLoss - signal.entryPrice) * riskReward;
         
         Print("🎯 TP محاسبه شد: ", DoubleToString(setup.takeProfit1, _Digits), 
               " | ریسک به ریوارد: ", riskReward, ":1");
      }
      
      setup.isValid = true;
      
      // ذخیره در لیست معاملات در انتظار
      int idx = ArraySize(pendingTrades);
      ArrayResize(pendingTrades, idx + 1);
      pendingTrades[idx] = setup;
      
      return setup;
   }
   
   //-------------------------------------------------------------------
   // بررسی همپوشانی پین بار
   //-------------------------------------------------------------------
   bool HasExcessiveOverlap(const MqlRates &candles[], int index, 
                           const SupportResistanceLevel &levels[], int levelCount)
   {
      if(index < 1) return false;
      
      MqlRates current = candles[index];
      
      // بررسی همپوشانی با کندل قبل
      double overlapRange = 0;
      
      if(current.high > candles[index-1].low && current.low < candles[index-1].high)
      {
         overlapRange = MathMin(current.high, candles[index-1].high) - 
                       MathMax(current.low, candles[index-1].low);
         
         double candleRange = current.high - current.low;
         if(overlapRange > candleRange * 0.7)  // بیش از 70% همپوشانی
            return true;
      }
      
      // بررسی همپوشانی با سطوح حمایت/مقاومت
      for(int i = 0; i < levelCount; i++)
      {
         if(MathAbs(current.close - levels[i].price) < current.close * 0.001)
         {
            if(levels[i].touchCount >= 3)  // سطوح قوی
               return true;
         }
      }
      
      return false;
   }
   
   //-------------------------------------------------------------------
   // تشخیص فیک بریک‌اوت
   //-------------------------------------------------------------------
   bool IsFakeBreakout(const MqlRates &candles[], int index, double level, bool isBreakoutUp)
   {
      if(index < 2) return false;
      
      MqlRates breakoutCandle = candles[index - 1];
      MqlRates currentCandle = candles[index];
      
      if(isBreakoutUp)
      {
         // کندل بریک‌اوت بالای سطح بسته شده
         if(breakoutCandle.close > level)
         {
            // کندل بعدی پایین سطح بسته شده
            if(currentCandle.close < level)
               return true;
         }
      }
      else
      {
         if(breakoutCandle.close < level)
         {
            if(currentCandle.close > level)
               return true;
         }
      }
      
      return false;
   }
   
   //-------------------------------------------------------------------
   // اضافه کردن پوزیشن جدید
   //-------------------------------------------------------------------
   int AddPosition(int ticket, const TradeSetup &setup)
   {
      int idx = ArraySize(activePositions);
      ArrayResize(activePositions, idx + 1);
      
      activePositions[idx].ticket = ticket;
      activePositions[idx].openTime = TimeCurrent();
      activePositions[idx].openPrice = setup.entryPrice;
      activePositions[idx].currentPrice = setup.entryPrice;
      activePositions[idx].stopLoss = setup.stopLoss;
      activePositions[idx].takeProfit = setup.takeProfit1;
      activePositions[idx].volume = setup.initialSize;  // فقط 20% اولیه
      activePositions[idx].isLong = setup.isLong;
      activePositions[idx].status = STATUS_POSITION_OPEN;
      activePositions[idx].riskAmount = MathAbs(setup.entryPrice - setup.stopLoss) * 
                                        setup.initialSize * 
                                        SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      // ثبت موفقیت SL (چون در این مرحله SL با موفقیت ثبت شده)
      RecordSLSuccess();
      
      return idx;
   }
   
   //-------------------------------------------------------------------
   // اضافه کردن به پوزیشن موجود (80% باقیمانده)
   //-------------------------------------------------------------------
   bool AddToPosition(int positionIndex, double additionalVolume)
   {
      if(positionIndex >= ArraySize(activePositions))
         return false;
      
      if(activePositions[positionIndex].status != STATUS_POSITION_OPEN)
         return false;
      
      activePositions[positionIndex].volume += additionalVolume;
      
      // ریسک کل به‌روز میشود
      activePositions[positionIndex].riskAmount = 
         MathAbs(activePositions[positionIndex].openPrice - 
                activePositions[positionIndex].stopLoss) * 
         activePositions[positionIndex].volume * 
         SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      return true;
   }
   
   //-------------------------------------------------------------------
   // بروزرسانی تریلینگ استاپ
   //-------------------------------------------------------------------
   bool UpdateTrailingStop(int positionIndex, double currentPrice)
   {
      if(positionIndex >= ArraySize(activePositions))
         return false;
      
      if(!riskParams.useTrailingStop)
         return false;
      
      PositionInfo &pos = activePositions[positionIndex];
      
      if(pos.isLong)
      {
         double profitPercent = (currentPrice - pos.openPrice) / pos.openPrice * 100;
         
         if(profitPercent >= riskParams.trailingActivation)
         {
            double newStop = currentPrice - (pos.openPrice * riskParams.trailingDistance / 100);
            
            if(newStop > pos.stopLoss)
            {
               pos.stopLoss = newStop;
               Print("📈 تریلینگ استاپ به‌روزرسانی شد - SL جدید: ", DoubleToString(newStop, _Digits));
               return true;
            }
         }
      }
      else
      {
         double profitPercent = (pos.openPrice - currentPrice) / pos.openPrice * 100;
         
         if(profitPercent >= riskParams.trailingActivation)
         {
            double newStop = currentPrice + (pos.openPrice * riskParams.trailingDistance / 100);
            
            if(newStop < pos.stopLoss || pos.stopLoss == 0)
            {
               pos.stopLoss = newStop;
               Print("📉 تریلینگ استاپ به‌روزرسانی شد - SL جدید: ", DoubleToString(newStop, _Digits));
               return true;
            }
         }
      }
      
      return false;
   }
   
   //-------------------------------------------------------------------
   // انتقال به بریک ایون
   //-------------------------------------------------------------------
   bool MoveToBreakeven(int positionIndex, double currentPrice)
   {
      if(positionIndex >= ArraySize(activePositions))
         return false;
      
      if(!riskParams.useBreakeven)
         return false;
      
      PositionInfo &pos = activePositions[positionIndex];
      
      if(pos.isLong)
      {
         double profitPercent = (currentPrice - pos.openPrice) / pos.openPrice * 100;
         
         if(profitPercent >= riskParams.breakevenActivation)
         {
            if(pos.stopLoss < pos.openPrice)
            {
               pos.stopLoss = pos.openPrice;
               Print("⚖️ انتقال به بریک ایون - SL به قیمت ورود منتقل شد: ", DoubleToString(pos.openPrice, _Digits));
               return true;
            }
         }
      }
      else
      {
         double profitPercent = (pos.openPrice - currentPrice) / pos.openPrice * 100;
         
         if(profitPercent >= riskParams.breakevenActivation)
         {
            if(pos.stopLoss > pos.openPrice || pos.stopLoss == 0)
            {
               pos.stopLoss = pos.openPrice;
               Print("⚖️ انتقال به بریک ایون - SL به قیمت ورود منتقل شد: ", DoubleToString(pos.openPrice, _Digits));
               return true;
            }
         }
      }
      
      return false;
   }
   
   //-------------------------------------------------------------------
   // بستن بخشی از پوزیشن
   //-------------------------------------------------------------------
   double ClosePartialPosition(int positionIndex, double closePercent, ENUM_EXIT_REASON reason)
   {
      if(positionIndex >= ArraySize(activePositions))
         return 0;
      
      PositionInfo &pos = activePositions[positionIndex];
      double closeVolume = pos.volume * (closePercent / 100);
      
      if(closeVolume >= pos.volume)
         return CloseFullPosition(positionIndex, reason);
      
      pos.volume -= closeVolume;
      pos.status = STATUS_PARTIAL_CLOSED;
      
      // محاسبه سود/زیان
      double profit = 0;
      if(pos.isLong)
         profit = (pos.currentPrice - pos.openPrice) * closeVolume * 
                  SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      else
         profit = (pos.openPrice - pos.currentPrice) * closeVolume * 
                  SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      dailyPnL += profit;
      
      Print("✂️ بستن جزئی پوزیشن - ", closePercent, "% | سود: ", DoubleToString(profit, 2), " USD");
      
      return profit;
   }
   
   //-------------------------------------------------------------------
   // بستن کامل پوزیشن
   //-------------------------------------------------------------------
   double CloseFullPosition(int positionIndex, ENUM_EXIT_REASON reason)
   {
      if(positionIndex >= ArraySize(activePositions))
         return 0;
      
      PositionInfo &pos = activePositions[positionIndex];
      
      // محاسبه سود/زیان
      double profit = 0;
      if(pos.isLong)
         profit = (pos.currentPrice - pos.openPrice) * pos.volume * 
                  SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      else
         profit = (pos.openPrice - pos.currentPrice) * pos.volume * 
                  SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      dailyPnL += profit;
      
      string reasonStr;
      switch(reason)
      {
         case EXIT_TAKE_PROFIT: reasonStr = "حد سود"; break;
         case EXIT_STOP_LOSS: reasonStr = "حد ضرر"; break;
         case EXIT_TRAILING_STOP: reasonStr = "تریلینگ استاپ"; break;
         case EXIT_REVERSAL_SIGNAL: reasonStr = "سیگنال برگشت"; break;
         case EXIT_MANUAL: reasonStr = "دستی"; break;
         case EXIT_TIME_BASED: reasonStr = "زمانی"; break;
         default: reasonStr = "نامشخص";
      }
      
      Print("🔚 بستن کامل پوزیشن - دلیل: ", reasonStr, " | سود: ", DoubleToString(profit, 2), " USD");
      
      pos.status = STATUS_FULLY_CLOSED;
      
      // حذف از آرایه
      for(int i = positionIndex; i < ArraySize(activePositions) - 1; i++)
         activePositions[i] = activePositions[i + 1];
      ArrayResize(activePositions, ArraySize(activePositions) - 1);
      
      return profit;
   }
   
   //-------------------------------------------------------------------
   // بررسی سیگنال خلاف جهت
   //-------------------------------------------------------------------
   bool CheckReversalSignal(int positionIndex, const SignalBar &reversalSignal)
   {
      if(positionIndex >= ArraySize(activePositions))
         return false;
      
      PositionInfo &pos = activePositions[positionIndex];
      
      // اگر سیگنال خلاف جهت پوزیشن فعلی باشد
      if(reversalSignal.isLong == !pos.isLong)
      {
         // قدرت سیگنال باید بالا باشد
         if(reversalSignal.strength >= 4)
         {
            CloseFullPosition(positionIndex, EXIT_REVERSAL_SIGNAL);
            return true;
         }
      }
      
      return false;
   }
   
   //-------------------------------------------------------------------
   // محاسبه حد ضرر بر اساس ATR یا نوسان
   //-------------------------------------------------------------------
   double CalculateAdaptiveStopLoss(const MqlRates &candles[], int index, bool isLong, int period = 14)
   {
      if(index < period) return 0;
      
      // محاسبه ATR ساده
      double atr = 0;
      for(int i = 0; i < period; i++)
      {
         double high = candles[index - i].high;
         double low = candles[index - i].low;
         double prevClose = (index - i - 1 >= 0) ? candles[index - i - 1].close : candles[index - i].open;
         
         double tr = MathMax(high - low, MathMax(MathAbs(high - prevClose), MathAbs(low - prevClose)));
         atr += tr;
      }
      atr /= period;
      
      if(isLong)
         return candles[index].low - atr * 1.5;
      else
         return candles[index].high + atr * 1.5;
   }
   
   //-------------------------------------------------------------------
   // بررسی محدودیت تعداد پوزیشن
   //-------------------------------------------------------------------
   bool CanOpenNewPosition()
   {
      int openCount = 0;
      
      for(int i = 0; i < ArraySize(activePositions); i++)
      {
         if(activePositions[i].status == STATUS_POSITION_OPEN ||
            activePositions[i].status == STATUS_PARTIAL_CLOSED)
            openCount++;
      }
      
      return (openCount < riskParams.maxPositions);
   }
   
   //-------------------------------------------------------------------
   // بررسی ریسک روزانه
   //-------------------------------------------------------------------
   bool IsDailyRiskExceeded()
   {
      return (dailyPnL <= -accountBalance * (riskParams.maxRiskPerDay / 100));
   }
   
   //-------------------------------------------------------------------
   // محاسبه سود/زیان شناور
   //-------------------------------------------------------------------
   double CalculateFloatingProfit()
   {
      double totalProfit = 0;
      
      for(int i = 0; i < ArraySize(activePositions); i++)
      {
         if(activePositions[i].status == STATUS_POSITION_OPEN ||
            activePositions[i].status == STATUS_PARTIAL_CLOSED)
         {
            if(activePositions[i].isLong)
               totalProfit += (activePositions[i].currentPrice - activePositions[i].openPrice) * 
                             activePositions[i].volume * 
                             SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            else
               totalProfit += (activePositions[i].openPrice - activePositions[i].currentPrice) * 
                             activePositions[i].volume * 
                             SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         }
      }
      
      return totalProfit;
   }
   
   //-------------------------------------------------------------------
   // ریست روزانه
   //-------------------------------------------------------------------
   void DailyReset()
   {
      datetime currentTime = TimeCurrent();
      
      if(TimeDay(currentTime) != TimeDay(lastResetTime))
      {
         dailyPnL = 0;
         lastResetTime = currentTime;
         
         // ریست وضعیت SL اجباری در شروع روز جدید
         ResetForcedSLStatus();
      }
   }
   
   //-------------------------------------------------------------------
   // دریافت آمار معاملات
   //-------------------------------------------------------------------
   string GetTradeStats()
   {
      string stats = "";
      stats += "══════════════════════════════════════════════\n";
      stats += "📊 آمار معاملات\n";
      stats += "══════════════════════════════════════════════\n";
      stats += "موجودی حساب: " + DoubleToString(accountBalance, 2) + " USD\n";
      stats += "سود/زیان روزانه: " + DoubleToString(dailyPnL, 2) + " USD\n";
      stats += "پوزیشن‌های باز: " + IntegerToString(ArraySize(activePositions)) + "\n";
      stats += "ریسک روزانه: " + DoubleToString(MathAbs(dailyPnL) / accountBalance * 100, 2) + "%\n";
      stats += "حداکثر ریسک مجاز: " + DoubleToString(riskParams.maxRiskPerDay, 2) + "%\n";
      
      // اضافه کردن آمار SL اجباری
      stats += "──────────────────────────────────────────\n";
      stats += "🚨 وضعیت SL اجباری:\n";
      stats += "   آخرین SL ناموفق: " + (lastTradeSLFailed ? "✅ بله" : "❌ خیر") + "\n";
      stats += "   دفعات متوالی: " + IntegerToString(consecutiveSLFailures) + "\n";
      stats += "   فاصله SL اجباری: " + DoubleToString(forcedSLDistance / pipValue, 1) + " پیپ\n";
      
      stats += "══════════════════════════════════════════════";
      
      return stats;
   }
   
   //-------------------------------------------------------------------
   // تنظیم حالت استفاده از کل سرمایه (برای هماهنگی با ربات اصلی)
   //-------------------------------------------------------------------
   void SetFullCapitalMode(bool useFullCapital)
   {
      // این متد برای هماهنگی با ربات اصلی اضافه شده
      if(useFullCapital)
         Print("💰 حالت کل سرمایه فعال شد");
      else
         Print("💰 حالت 20/80 فعال شد");
   }
};