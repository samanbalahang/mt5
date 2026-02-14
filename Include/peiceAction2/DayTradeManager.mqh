//+------------------------------------------------------------------+
//|                                                     DayTradeManager.mqh |
//|                                        مدیریت روزهای معاملاتی و محدودیت ضرر |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| ساختار وضعیت معاملاتی روز (شیء TradeAbleDay)
//+------------------------------------------------------------------+
struct TradeAbleDay
{
   int               day;              // تاریخ روز (20250511)
   bool              tradeable;        // آیا امروز قابل معامله است؟
   int               lossCount;        // تعداد ضررهای امروز
   int               winCount;         // تعداد سودهای امروز
   double            totalProfit;      // سود/ضرر کل امروز
   
   // سازنده پیش‌فرض
   TradeAbleDay()
   {
      day = 0;
      tradeable = true;
      lossCount = 0;
      winCount = 0;
      totalProfit = 0;
   }
   
   // سازنده با تاریخ
   TradeAbleDay(int newDay)
   {
      day = newDay;
      tradeable = true;
      lossCount = 0;
      winCount = 0;
      totalProfit = 0;
   }
};

//+------------------------------------------------------------------+
//| کلاس مدیریت روزهای معاملاتی
//+------------------------------------------------------------------+
class CDayTradeManager
{
private:
   TradeAbleDay       days[];           // آرایه روزهای معاملاتی
   int                maxDays;          // حداکثر روزهای ذخیره شده
   int                currentDay;       // روز جاری
   
public:
   // سازنده
   CDayTradeManager()
   {
      maxDays = 365;  // ذخیره یک سال
      ArrayResize(days, 0);
      currentDay = 0;
      UpdateCurrentDay();
   }
   
   // به‌روزرسانی روز جاری
   void UpdateCurrentDay()
   {
      MqlDateTime dt;
      TimeToCurrent(dt);
      currentDay = dt.year * 10000 + dt.mon * 100 + dt.day;
   }
   
   // دریافت یا ایجاد وضعیت روز
   TradeAbleDay* GetOrCreateDay(int day)
   {
      // جستجوی روز در آرایه
      for(int i = 0; i < ArraySize(days); i++)
      {
         if(days[i].day == day)
            return &days[i];
      }
      
      // اگر روز وجود نداشت، ایجاد کن
      int index = ArraySize(days);
      if(index < maxDays)
      {
         ArrayResize(days, index + 1);
         days[index].day = day;
         days[index].tradeable = true;
         days[index].lossCount = 0;
         days[index].winCount = 0;
         days[index].totalProfit = 0;
         return &days[index];
      }
      
      return NULL;
   }
   
   // دریافت وضعیت روز جاری
   TradeAbleDay* GetCurrentDay()
   {
      UpdateCurrentDay();
      return GetOrCreateDay(currentDay);
   }
   
   // بررسی قابلیت معامله در روز جاری
   bool IsTodayTradeable()
   {
      TradeAbleDay* today = GetCurrentDay();
      if(today == NULL) return true;
      
      return today.tradeable;
   }
   
   // ثبت نتیجه معامله
   void RecordTradeResult(double profit)
   {
      TradeAbleDay* today = GetCurrentDay();
      if(today == NULL) return;
      
      // به‌روزرسانی آمار
      today.totalProfit += profit;
      
      if(profit > 0)
      {
         today.winCount++;
         Print("✅ سود ثبت شد - سودهای امروز: ", today.winCount);
      }
      else if(profit < 0)
      {
         today.lossCount++;
         Print("❌ ضرر ثبت شد - ضررهای امروز: ", today.lossCount);
      }
   }
   
   // بررسی و اعمال محدودیت ضرر روزانه
   bool CheckAndApplyDailyLossLimit(int maxDailyLoss)
   {
      TradeAbleDay* today = GetCurrentDay();
      if(today == NULL) return false;
      
      if(today.lossCount >= maxDailyLoss && today.tradeable)
      {
         today.tradeable = false;
         Print("══════════════════════════════════════════════");
         Print("🚫 توقف معاملات در روز ", today.day);
         Print("   دلیل: ", today.lossCount, " معامله ضرر");
         Print("   حداکثر مجاز: ", maxDailyLoss);
         Print("══════════════════════════════════════════════");
         return true;
      }
      
      return false;
   }
   
   // بررسی شروع روز جدید
   bool IsNewDay()
   {
      int oldDay = currentDay;
      UpdateCurrentDay();
      return (currentDay != oldDay);
   }
   
   // ریست وضعیت روز جدید
   void ResetForNewDay()
   {
      // روز جدید را ایجاد کن (اگر وجود نداشت)
      GetCurrentDay();
      Print("📅 روز جدید معاملاتی: ", currentDay);
   }
   
   // دریافت آمار روز
   string GetDayStats(int day)
   {
      TradeAbleDay* targetDay = GetOrCreateDay(day);
      if(targetDay == NULL) return "روز یافت نشد";
      
      string result = "\n";
      StringConcatenate(result,
         "══════════════════════════════════════════════\n",
         "📊 آمار روز ", day, "\n",
         "══════════════════════════════════════════════\n",
         "📈 وضعیت: ", targetDay.tradeable ? "✅ قابل معامله" : "🚫 غیرقابل معامله", "\n",
         "✅ تعداد سود: ", targetDay.winCount, "\n",
         "❌ تعداد ضرر: ", targetDay.lossCount, "\n",
         "💰 سود خالص: ", DoubleToString(targetDay.totalProfit, 2), " USD\n",
         "══════════════════════════════════════════════"
      );
      
      return result;
   }
   
   // دریافت آمار روز جاری
   string GetTodayStats()
   {
      return GetDayStats(currentDay);
   }
   
   // دریافت تمام روزها برای نمایش
   int GetAllDays(TradeAbleDay &result[])
   {
      ArrayResize(result, ArraySize(days));
      for(int i = 0; i < ArraySize(days); i++)
         result[i] = days[i];
      return ArraySize(days);
   }
   
   // نمایش تمام روزها در قالب JSON
   void PrintAllDaysAsJSON()
   {
      Print("══════════════════════════════════════════════");
      Print("📋 تاریخچه روزهای معاملاتی:");
      Print("[");
      
      for(int i = 0; i < ArraySize(days); i++)
      {
         Print("  {");
         Print("    day: ", days[i].day, ",");
         Print("    tradeable: ", days[i].tradeable ? "true" : "false", ",");
         Print("    lossCount: ", days[i].lossCount, ",");
         Print("    winCount: ", days[i].winCount, ",");
         Print("    totalProfit: ", DoubleToString(days[i].totalProfit, 2));
         
         if(i < ArraySize(days) - 1)
            Print("  },");
         else
            Print("  }");
      }
      
      Print("]");
      Print("══════════════════════════════════════════════");
   }
   
   // ذخیره در فایل
   bool SaveToFile(string filename)
   {
      int handle = FileOpen(filename, FILE_WRITE|FILE_BIN|FILE_COMMON);
      if(handle == INVALID_HANDLE)
      {
         Print("❌ خطا در باز کردن فایل برای ذخیره وضعیت روزها");
         return false;
      }
      
      int size = ArraySize(days);
      FileWriteInteger(handle, size);
      FileWriteInteger(handle, currentDay);
      
      for(int i = 0; i < size; i++)
      {
         FileWriteStruct(handle, days[i]);
      }
      
      FileClose(handle);
      Print("💾 وضعیت روزهای معاملاتی ذخیره شد - ", filename);
      return true;
   }
   
   // بارگذاری از فایل
   bool LoadFromFile(string filename)
   {
      int handle = FileOpen(filename, FILE_READ|FILE_BIN|FILE_COMMON);
      if(handle == INVALID_HANDLE)
         return false;
      
      int size = FileReadInteger(handle);
      currentDay = FileReadInteger(handle);
      ArrayResize(days, size);
      
      for(int i = 0; i < size; i++)
      {
         FileReadStruct(handle, days[i]);
      }
      
      FileClose(handle);
      Print("📂 وضعیت روزهای معاملاتی بارگذاری شد - ", filename, " (", size, " روز)");
      return true;
   }
};