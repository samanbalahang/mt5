//+------------------------------------------------------------------+
//|                                                  MarketSessionManager.mqh |
//|                                        تشخیص باز/بسته بودن بازار |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"

enum ENUM_MARKET_STATUS
{
   MARKET_OPEN,           // بازار باز است
   MARKET_CLOSED,         // بازار بسته است
   MARKET_UNKNOWN         // وضعیت نامشخص
};

class CMarketSessionManager
{
private:
   string            symbol;           // نماد مورد نظر
   int               serverTimezone;   // منطقه زمانی سرور
   int               brokerDigits;     // تعداد ارقام اعشار
   
public:
   // سازنده
   CMarketSessionManager(void)
   {
      symbol = _Symbol;
      serverTimezone = 0;
      brokerDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   }
   
   // تنظیم نماد
   void SetSymbol(string sym)
   {
      symbol = sym;
   }
   
   //-------------------------------------------------------------------
   // بررسی باز بودن بازار در لحظه فعلی
   //-------------------------------------------------------------------
   bool IsMarketOpen()
   {
      return IsMarketOpenAtTime(TimeCurrent());
   }
   
   //-------------------------------------------------------------------
   // بررسی باز بودن بازار در زمان مشخص
   //-------------------------------------------------------------------
   bool IsMarketOpenAtTime(datetime checkTime)
   {
      // دریافت اطلاعات روز و زمان
      MqlDateTime dt;
      TimeToStruct(checkTime, dt);
      
      // دریافت روز هفته (0=Sunday, 1=Monday, ..., 6=Saturday)
      ENUM_DAY_OF_WEEK dayOfWeek = (ENUM_DAY_OF_WEEK)dt.day_of_week;
      
      // محاسبه ثانیه‌های گذشته از نیمه‌شب
      int currentSeconds = dt.hour * 3600 + dt.min * 60 + dt.sec;
      
      // بررسی تمام سشن‌های معاملاتی برای این روز
      int sessionIndex = 0;
      datetime sessionStart, sessionEnd;
      
      while(true)
      {
         // دریافت اطلاعات سشن معاملاتی
         if(!SymbolInfoSessionTrade(symbol, dayOfWeek, sessionIndex, sessionStart, sessionEnd))
            break;  // سشن دیگری وجود ندارد
         
         // تبدیل به ثانیه از نیمه‌شب
         MqlDateTime startDt, endDt;
         TimeToStruct(sessionStart, startDt);
         TimeToStruct(sessionEnd, endDt);
         
         int startSeconds = startDt.hour * 3600 + startDt.min * 60 + startDt.sec;
         int endSeconds = endDt.hour * 3600 + endDt.min * 60 + endDt.sec;
         
         // بررسی حالت خاص: سشن شبانه که از یک روز به روز بعد کشیده می‌شود
         if(endSeconds < startSeconds)  // مثلاً 21:00 تا 05:00 روز بعد
         {
            // اگر زمان فعلی بزرگتر از شروع یا کوچکتر از پایان باشد
            if(currentSeconds >= startSeconds || currentSeconds < endSeconds)
            {
               return true;
            }
         }
         else  // سشن عادی در طول یک روز
         {
            if(currentSeconds >= startSeconds && currentSeconds < endSeconds)
            {
               return true;
            }
         }
         
         sessionIndex++;
      }
      
      return false;  // هیچ سشن فعالی یافت نشد
   }
   
   //-------------------------------------------------------------------
   // دریافت زمان باز شدن بعدی بازار
   //-------------------------------------------------------------------
   datetime GetNextMarketOpenTime()
   {
      datetime currentTime = TimeCurrent();
      
      // بررسی 7 روز آینده
      for(int dayOffset = 0; dayOffset < 7; dayOffset++)
      {
         datetime checkDay = currentTime + dayOffset * 24 * 3600;
         MqlDateTime dt;
         TimeToStruct(checkDay, dt);
         
         ENUM_DAY_OF_WEEK dayOfWeek = (ENUM_DAY_OF_WEEK)dt.day_of_week;
         
         int sessionIndex = 0;
         datetime sessionStart, sessionEnd;
         
         while(true)
         {
            if(!SymbolInfoSessionTrade(symbol, dayOfWeek, sessionIndex, sessionStart, sessionEnd))
               break;
            
            // اگر امروز را بررسی می‌کنیم، فقط سشن‌های بعد از زمان فعلی
            if(dayOffset == 0)
            {
               MqlDateTime startDt;
               TimeToStruct(sessionStart, startDt);
               int startSeconds = startDt.hour * 3600 + startDt.min * 60 + startDt.sec;
               int currentSeconds = dt.hour * 3600 + dt.min * 60 + dt.sec;
               
               if(startSeconds > currentSeconds)
               {
                  // ساخت زمان دقیق باز شدن
                  datetime openTime = checkDay;
                  openTime -= currentSeconds;
                  openTime += startSeconds;
                  return openTime;
               }
            }
            else
            {
               // برای روزهای آینده، اولین سشن را برمی‌گردانیم
               MqlDateTime startDt;
               TimeToStruct(sessionStart, startDt);
               int startSeconds = startDt.hour * 3600 + startDt.min * 60 + startDt.sec;
               
               datetime openTime = checkDay;
               openTime = openTime / 86400 * 86400;  // برش به نیمه‌شب
               openTime += startSeconds;
               return openTime;
            }
            
            sessionIndex++;
         }
      }
      
      return 0;  // هیچ سشن‌ای یافت نشد
   }
   
   //-------------------------------------------------------------------
   // دریافت زمان بسته شدن بعدی بازار
   //-------------------------------------------------------------------
   datetime GetNextMarketCloseTime()
   {
      datetime currentTime = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      ENUM_DAY_OF_WEEK dayOfWeek = (ENUM_DAY_OF_WEEK)dt.day_of_week;
      int currentSeconds = dt.hour * 3600 + dt.min * 60 + dt.sec;
      
      int sessionIndex = 0;
      datetime sessionStart, sessionEnd;
      
      while(true)
      {
         if(!SymbolInfoSessionTrade(symbol, dayOfWeek, sessionIndex, sessionStart, sessionEnd))
            break;
         
         MqlDateTime endDt;
         TimeToStruct(sessionEnd, endDt);
         int endSeconds = endDt.hour * 3600 + endDt.min * 60 + endDt.sec;
         
         // اگر سشن بعد از زمان فعلی بسته می‌شود
         if(endSeconds > currentSeconds)
         {
            datetime closeTime = currentTime;
            closeTime -= currentSeconds;
            closeTime += endSeconds;
            return closeTime;
         }
         
         sessionIndex++;
      }
      
      // اگر امروز سشن دیگری نیست، اولین سشن فردا را پیدا کن
      return GetNextMarketOpenTime() + 1;  // تقریب
   }
   
   //-------------------------------------------------------------------
   // دریافت وضعیت بازار به صورت متنی
   //-------------------------------------------------------------------
   string GetMarketStatusText()
   {
      if(IsMarketOpen())
      {
         datetime closeTime = GetNextMarketCloseTime();
         int minutesLeft = (int)((closeTime - TimeCurrent()) / 60);
         
         return StringFormat("✅ بازار باز است - زمان بسته شدن: %s (%d دقیقه دیگر)", 
                            TimeToString(closeTime, TIME_MINUTES), minutesLeft);
      }
      else
      {
         datetime openTime = GetNextMarketOpenTime();
         if(openTime > 0)
         {
            int minutesLeft = (int)((openTime - TimeCurrent()) / 60);
            return StringFormat("❌ بازار بسته است - زمان باز شدن: %s (%d دقیقه دیگر)", 
                               TimeToString(openTime, TIME_MINUTES), minutesLeft);
         }
         else
         {
            return "❌ بازار بسته است - زمان باز شدن نامشخص";
         }
      }
   }
   
   //-------------------------------------------------------------------
   // نمایش تمام سشن‌های معاملاتی
   //-------------------------------------------------------------------
   void PrintAllSessions()
   {
      Print("══════════════════════════════════════════════");
      Print("📅 سشن‌های معاملاتی برای ", symbol);
      Print("══════════════════════════════════════════════");
      
      string days[7] = {"یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنج‌شنبه", "جمعه", "شنبه"};
      
      for(int day = 0; day < 7; day++)
      {
         ENUM_DAY_OF_WEEK dayOfWeek = (ENUM_DAY_OF_WEEK)day;
         int sessionIndex = 0;
         bool hasSession = false;
         
         while(true)
         {
            datetime sessionStart, sessionEnd;
            if(!SymbolInfoSessionTrade(symbol, dayOfWeek, sessionIndex, sessionStart, sessionEnd))
               break;
            
            if(!hasSession)
            {
               Print(days[day], ":");
               hasSession = true;
            }
            
            Print("   سشن ", sessionIndex + 1, ": ", 
                  TimeToString(sessionStart, TIME_MINUTES), " - ", 
                  TimeToString(sessionEnd, TIME_MINUTES));
            
            sessionIndex++;
         }
         
         if(!hasSession)
            Print(days[day], ": تعطیل");
      }
      
      Print("══════════════════════════════════════════════");
   }
};