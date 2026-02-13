//+------------------------------------------------------------------+
//| کلاس نمایش و هشدارها                                            |
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

#include "Structures.mqh"

class CVisualDisplay
{
private:
   bool      m_enableAlerts;
   bool      m_drawTrendlines;
   bool      m_drawZones;
   bool      m_drawFibos;
   color     m_uptrendColor;
   color     m_downtrendColor;
   
public:
   CVisualDisplay();
   ~CVisualDisplay();
   
   void SetParameters(bool alerts, bool drawTL, bool drawZones, bool drawFibos, 
                      color upColor, color downColor);
   
   // رسم خط روند
   void DrawTrendLine(string name, datetime time1, double price1, datetime time2, double price2, color lineColor);
   
   // رسم ناحیه ورود
   void DrawEntryZone(string name, datetime time, double top, double bottom, color zoneColor);
   
   // رسم فیبوناچی
   void DrawFibonacci(string name, datetime time1, double price1, datetime time2, double price2);
   
   // نمایش هشدار
   void ShowAlert(string message, bool isBreakout);
   
   // نمایش اطلاعات روی چارت
   void DisplayInfo(string &info[]);
   
   // پاک کردن اشیاء
   void ClearObjects(string prefix);
};

//+------------------------------------------------------------------+
//| پیاده‌سازی                                                     |
//+------------------------------------------------------------------+
CVisualDisplay::CVisualDisplay()
{
   m_enableAlerts = true;
   m_drawTrendlines = true;
   m_drawZones = true;
   m_drawFibos = true;
   m_uptrendColor = clrDodgerBlue;
   m_downtrendColor = clrCrimson;
}

//+------------------------------------------------------------------+
//| نمایش هشدار                                                     |
//+------------------------------------------------------------------+
void CVisualDisplay::ShowAlert(string message, bool isBreakout)
{
   if(!m_enableAlerts) return;
   
   if(isBreakout)
      Alert("🚀 شکست خط روند: ", message);
   else
      Alert("📊 سیگنال ورود: ", message);
   
   Print(TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), " | ", message);
}