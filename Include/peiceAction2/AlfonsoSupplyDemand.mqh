//+------------------------------------------------------------------+
//|                                                  AlfonsoSupplyDemand.mqh |
//|                                     تشخیص سطوح عرضه و تقاضا به روش آلفونسو مورنو |
//+------------------------------------------------------------------+
#property copyright "Albrooks Style System"
#property version   "1.00"
#property strict

#include "TrendChannelDetector.mqh"

enum ENUM_SD_TYPE
{
   SD_NONE,
   SD_SUPPLY,        // عرضه (منطقه فروش)
   SD_DEMAND         // تقاضا (منطقه خرید)
};

enum ENUM_SD_FRESHNESS
{
   FRESH,            // تازه - هنوز پولبک نخورده
   TESTED,           // یک بار تست شده
   CONSUMED          // مصرف‌شده - چند بار تست شده
};

struct SupplyDemandZone
{
   double            proximal;      // خط نزدیک به قیمت (Proximal)
   double            distal;        // خط دور از قیمت (Distal)
   datetime          formationTime; // زمان تشکیل
   ENUM_SD_TYPE      type;          // عرضه یا تقاضا
   ENUM_SD_FRESHNESS freshness;     // تازگی
   int               touches;       // تعداد برخورد
   double            strength;      // قدرت (بر اساس شدت حرکت)
   bool              isValid;
};

class CAlfonsoSupplyDemand
{
private:
   TrendChannelDetector  trendDetector;
   SupplyDemandZone      zones[];
   int                   maxZones;
   double                minZoneHeight;     // حداقل ارتفاع منطقه (بر حسب پیپ)
   double                touchTolerance;    // تلورانس برخورد
   double                spikeThreshold;    // آستانه تشخیص حرکت قوی (بر حسب درصد)
   
public:
   CAlfonsoSupplyDemand()
   {
      maxZones = 100;
      minZoneHeight = 10 * GetPipValue();   // حداقل 10 پیپ
      touchTolerance = 0.0005;               // 0.05%
      spikeThreshold = 0.5;                   // 0.5% برای حرکت قوی
      ArrayResize(zones, 0);
   }
   
   // دریافت ارزش پیپ
   double GetPipValue()
   {
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(digits == 5 || digits == 3) return point * 10;
      else return point;
   }
   
   // تشخیص حرکت قوی (spike) برای تأیید سطح
   bool IsStrongMove(const MqlRates &candles[], int start, int end, bool isUp)
   {
      double startPrice = isUp ? candles[start].low : candles[start].high;
      double endPrice = isUp ? candles[end].high : candles[end].low;
      double movePercent = MathAbs(endPrice - startPrice) / startPrice * 100;
      return movePercent >= spikeThreshold;
   }
   
   // اضافه کردن منطقه جدید
   void AddZone(double prox, double dist, datetime time, ENUM_SD_TYPE type)
   {
      // بررسی تکراری نبودن
      for(int i = 0; i < ArraySize(zones); i++)
      {
         if(MathAbs(zones[i].proximal - prox) < prox * touchTolerance &&
            zones[i].type == type)
         {
            zones[i].touches++;
            if(zones[i].touches == 1) zones[i].freshness = TESTED;
            else if(zones[i].touches >= 2) zones[i].freshness = CONSUMED;
            return;
         }
      }
      
      int idx = ArraySize(zones);
      if(idx >= maxZones)
      {
         // حذف قدیمی‌ترین
         for(int i = 0; i < idx-1; i++) zones[i] = zones[i+1];
         idx--;
      }
      ArrayResize(zones, idx+1);
      zones[idx].proximal = prox;
      zones[idx].distal = dist;
      zones[idx].formationTime = time;
      zones[idx].type = type;
      zones[idx].freshness = FRESH;
      zones[idx].touches = 0;
      zones[idx].strength = 0;
      zones[idx].isValid = true;
   }
   
   // تشخیص سطوح از روی کندل‌ها
   void ScanZones(const MqlRates &candles[], int total)
   {
      // نیاز به حداقل 50 کندل
      if(total < 50) return;
      
      // پیدا کردن نقاط نوسانی (swing highs/lows)
      for(int i = 20; i < total - 5; i++)
      {
         // تشخیص کف (demand) با الگوی صعود-پایه-صعود
         if(trendDetector.IsSwingLow(candles, i, 2))
         {
            // بررسی وجود پایه (چند کندل کوچک قبل از حرکت قوی)
            int baseStart = i;
            int baseEnd = i;
            bool foundBase = false;
            for(int j = i-1; j >= i-5 && j>=0; j--)
            {
               if(candles[j].high - candles[j].low < (candles[i].high - candles[i].low) * 0.3)
               {
                  baseStart = j;
                  foundBase = true;
               }
               else break;
            }
            if(!foundBase) continue;
            
            // بررسی حرکت صعودی قوی بعد از پایه
            if(IsStrongMove(candles, i, i+3, true))
            {
               double proximal = candles[baseStart].low;   // نزدیک‌ترین سطح
               double distal = candles[baseEnd].high;      // دورترین سطح (می‌تواند اصلاح شود)
               AddZone(proximal, distal, candles[i].time, SD_DEMAND);
            }
         }
         
         // تشخیص سقف (supply) با الگوی نزول-پایه-نزول
         if(trendDetector.IsSwingHigh(candles, i, 2))
         {
            int baseStart = i;
            int baseEnd = i;
            bool foundBase = false;
            for(int j = i-1; j >= i-5 && j>=0; j--)
            {
               if(candles[j].high - candles[j].low < (candles[i].high - candles[i].low) * 0.3)
               {
                  baseStart = j;
                  foundBase = true;
               }
               else break;
            }
            if(!foundBase) continue;
            
            if(IsStrongMove(candles, i, i+3, false))
            {
               double proximal = candles[baseStart].high;  // نزدیک‌ترین سطح
               double distal = candles[baseEnd].low;
               AddZone(proximal, distal, candles[i].time, SD_SUPPLY);
            }
         }
      }
   }
   
   // تشخیص پولبک به یک سطح
   bool IsPullbackToZone(const MqlRates &candle, const SupplyDemandZone &zone, bool isLong)
   {
      if(isLong) // برای خرید، باید قیمت به منطقه تقاضا برگردد
      {
         if(zone.type != SD_DEMAND) return false;
         // قیمت پایین (یا نزدیک) خط proximal
         if(candle.low <= zone.proximal * (1 + touchTolerance) &&
            candle.close > zone.proximal)
            return true;
      }
      else // برای فروش، به منطقه عرضه
      {
         if(zone.type != SD_SUPPLY) return false;
         if(candle.high >= zone.proximal * (1 - touchTolerance) &&
            candle.close < zone.proximal)
            return true;
      }
      return false;
   }
   
   // تولید سیگنال بر اساس آخرین کندل
   SignalBar DetectSignal(const MqlRates &candles[], int index, ENUM_TREND_DIRECTION higherTrend)
   {
      SignalBar signal;
      signal.type = SIGNAL_NONE;
      
      if(index < 1) return signal;
      
      MqlRates current = candles[index];
      
      for(int i = 0; i < ArraySize(zones); i++)
      {
         if(!zones[i].isValid) continue;
         
         // فقط سطوح تازه یا یک بار تست شده
         if(zones[i].freshness == CONSUMED) continue;
         
         // تشخیص پولبک
         if(IsPullbackToZone(current, zones[i], true)) // سیگنال خرید
         {
            // بررسی هماهنگی با روند بالاتر
            if(higherTrend == TREND_UP || higherTrend == TREND_SIDEWAYS)
            {
               signal.type = SIGNAL_PINBAR; // یا یک نوع جدید
               signal.isLong = true;
               signal.entryPrice = current.high; // ورود بالای کندل
               signal.stopLoss = zones[i].distal * 0.999; // کمی پایین‌تر از distal
               signal.takeProfit1 = 0; // بعداً محاسبه شود
               signal.time = current.time;
               signal.strength = (zones[i].freshness == FRESH) ? 5 : 4;
               signal.description = StringFormat("Alfonso Demand Zone (Fresh: %s)", 
                                    (zones[i].freshness == FRESH) ? "Yes" : "Tested");
               break;
            }
         }
         else if(IsPullbackToZone(current, zones[i], false)) // سیگنال فروش
         {
            if(higherTrend == TREND_DOWN || higherTrend == TREND_SIDEWAYS)
            {
               signal.type = SIGNAL_PINBAR;
               signal.isLong = false;
               signal.entryPrice = current.low;
               signal.stopLoss = zones[i].distal * 1.001;
               signal.takeProfit1 = 0;
               signal.time = current.time;
               signal.strength = (zones[i].freshness == FRESH) ? 5 : 4;
               signal.description = StringFormat("Alfonso Supply Zone (Fresh: %s)", 
                                    (zones[i].freshness == FRESH) ? "Yes" : "Tested");
               break;
            }
         }
      }
      
      return signal;
   }
   
   // پاکسازی سطوح قدیمی
   void CleanOldZones(datetime currentTime, int daysToKeep = 30)
   {
      for(int i = ArraySize(zones)-1; i >= 0; i--)
      {
         if(currentTime - zones[i].formationTime > daysToKeep * 86400)
         {
            for(int j = i; j < ArraySize(zones)-1; j++)
               zones[j] = zones[j+1];
            ArrayResize(zones, ArraySize(zones)-1);
         }
      }
   }
   
   int GetZonesCount() { return ArraySize(zones); }
};