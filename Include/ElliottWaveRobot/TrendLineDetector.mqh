//+------------------------------------------------------------------+
//|                                                TrendLineDetector.mqh
//|                                     EURUSD Complete Breakout System v8.3
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

//+------------------------------------------------------------------+
//| شامل کردن ساختارهای مورد نیاز
//+------------------------------------------------------------------+
#include "Structures.mqh"

//+------------------------------------------------------------------+
//| کلاس تشخیص و مدیریت خطوط روند
//+------------------------------------------------------------------+
class CTrendLineDetector
{
private:
    // پارامترهای ورودی
    int      m_lookbackPeriod;
    int      m_swingPointsLookback;
    double   m_minTrendlineAngle;
    int      m_breakoutConfirmationBars;
    double   m_breakoutThreshold;
    double   m_volumeSpikeFactor;
    bool     m_drawTrendlines;
    
    // آرایه خطوط روند
    TrendLine m_trendlines[20];  // افزایش به 20 خط
    int       m_totalTrendlines;
    
    // رنگ‌ها
    color     m_uptrendColor;
    color     m_downtrendColor;
    
    // متدهای خصوصی
    bool      FindSwingPoints(double &highs[], double &lows[], int &highBars[], int &lowBars[]);
    bool      ValidateTrendline(const TrendLine &line);
    double    CalculateAngle(double price1, double price2, int barsDistance);
    bool      CheckBreakout(const TrendLine &line, bool isUptrend, double &breakPrice);
    bool      CheckVolumeSpike(int index);
    bool      IsPriceTouchingLine(double price, double lineValue, double tolerance);
    int       CountTouchPoints(const TrendLine &line);
    double    CalculateLineValue(const TrendLine &line, int barShift);
    bool      IsLineValidByAngle(const TrendLine &line);
    bool      IsLineValidByTouches(const TrendLine &line);
    
public:
    // سازنده و مخرب
    CTrendLineDetector();
    ~CTrendLineDetector();
    
    // تنظیم پارامترها
    void SetParameters(int lookback, int swingLookback, double minAngle, 
                      int confirmBars, double threshold, double volumeFactor, 
                      bool draw, color upColor, color downColor);
    
    // تشخیص خطوط روند
    int  DetectTrendlines();
    
    // بررسی شکست
    int  CheckBreakouts(bool &isBuy, double &breakPrice, int &brokenIndex);
    
    // دریافت خط روند
    bool GetTrendline(int index, TrendLine &line);
    
    // دریافت تعداد خطوط
    int  GetTotalTrendlines() { return m_totalTrendlines; }
    
    // پاک کردن اشیاء گرافیکی
    void ClearObjects();
    
    // رسم خطوط
    void DrawTrendlines();
    
    // به‌روزرسانی مقادیر جاری خطوط
    void UpdateCurrentValues();
    
    // دریافت مقدار جاری خط
    double GetCurrentLineValue(int index);
    
    // بررسی اینکه قیمت بالای/پایین خط است
    bool IsPriceAboveLine(int index, double price);
    bool IsPriceBelowLine(int index, double price);
};

//+------------------------------------------------------------------+
//| سازنده کلاس
//+------------------------------------------------------------------+
CTrendLineDetector::CTrendLineDetector()
{
    // مقداردهی اولیه پارامترها
    m_lookbackPeriod = 150;
    m_swingPointsLookback = 60;
    m_minTrendlineAngle = 8.0;
    m_breakoutConfirmationBars = 2;
    m_breakoutThreshold = 0.0008;
    m_volumeSpikeFactor = 1.3;
    m_drawTrendlines = true;
    m_uptrendColor = clrDodgerBlue;
    m_downtrendColor = clrCrimson;
    
    // ریست خطوط
    m_totalTrendlines = 0;
    for(int i = 0; i < 20; i++)
    {
        m_trendlines[i].touchCount = 0;
        m_trendlines[i].isUpTrend = false;
        m_trendlines[i].startBar = 0;
        m_trendlines[i].endBar = 0;
        m_trendlines[i].startPrice = 0;
        m_trendlines[i].endPrice = 0;
        m_trendlines[i].slope = 0;
        m_trendlines[i].angle = 0;
        m_trendlines[i].lastBreakTime = 0;
        m_trendlines[i].trendlineName = "";
        m_trendlines[i].currentValue = 0;
        m_trendlines[i].brokenTrendlineIndex = -1;
    }
}

//+------------------------------------------------------------------+
//| مخرب کلاس
//+------------------------------------------------------------------+
CTrendLineDetector::~CTrendLineDetector()
{
    if(m_drawTrendlines)
        ClearObjects();
}

//+------------------------------------------------------------------+
//| تنظیم پارامترها
//+------------------------------------------------------------------+
void CTrendLineDetector::SetParameters(int lookback, int swingLookback, double minAngle, 
                                      int confirmBars, double threshold, double volumeFactor, 
                                      bool draw, color upColor, color downColor)
{
    m_lookbackPeriod = lookback;
    m_swingPointsLookback = swingLookback;
    m_minTrendlineAngle = minAngle;
    m_breakoutConfirmationBars = confirmBars;
    m_breakoutThreshold = threshold;
    m_volumeSpikeFactor = volumeFactor;
    m_drawTrendlines = draw;
    m_uptrendColor = upColor;
    m_downtrendColor = downColor;
}

//+------------------------------------------------------------------+
//| یافتن نقاط سوینگ (قله‌ها و دره‌ها)
//+------------------------------------------------------------------+
bool CTrendLineDetector::FindSwingPoints(double &highs[], double &lows[], 
                                        int &highBars[], int &lowBars[])
{
    int bars = m_swingPointsLookback;
    ArrayResize(highs, bars);
    ArrayResize(lows, bars);
    ArrayResize(highBars, bars);
    ArrayResize(lowBars, bars);
    
    // دریافت داده‌های قیمتی
    for(int i = 0; i < bars; i++)
    {
        highs[i] = iHigh(_Symbol, PERIOD_H4, i);
        lows[i] = iLow(_Symbol, PERIOD_H4, i);
        highBars[i] = i;
        lowBars[i] = i;
    }
    
    int highCount = 0;
    int lowCount = 0;
    
    // یافتن قله‌های ماژور (نقاط بالاتر از 5 کندل اطراف)
    for(int i = 5; i < bars - 5; i++)
    {
        // بررسی قله
        bool isPeak = true;
        for(int j = 1; j <= 5; j++)
        {
            if(highs[i] <= highs[i - j] || highs[i] <= highs[i + j])
            {
                isPeak = false;
                break;
            }
        }
        
        if(isPeak)
        {
            highs[highCount] = highs[i];
            highBars[highCount] = i;
            highCount++;
        }
        
        // بررسی دره
        bool isTrough = true;
        for(int j = 1; j <= 5; j++)
        {
            if(lows[i] >= lows[i - j] || lows[i] >= lows[i + j])
            {
                isTrough = false;
                break;
            }
        }
        
        if(isTrough)
        {
            lows[lowCount] = lows[i];
            lowBars[lowCount] = i;
            lowCount++;
        }
    }
    
    // تنظیم سایز آرایه‌ها به تعداد واقعی
    ArrayResize(highs, highCount);
    ArrayResize(lows, lowCount);
    ArrayResize(highBars, highCount);
    ArrayResize(lowBars, lowCount);
    
    return (highCount > 1 && lowCount > 1);
}

//+------------------------------------------------------------------+
//| محاسبه زاویه خط روند
//+------------------------------------------------------------------+
double CTrendLineDetector::CalculateAngle(double price1, double price2, int barsDistance)
{
    if(barsDistance == 0) return 0;
    
    double priceDiff = MathAbs(price2 - price1);
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    double barsInAngle = barsDistance;
    
    // محاسبه زاویه بر حسب درجه
    if(priceDiff == 0) return 0;
    
    double angle = MathArctan(priceDiff / (pipSize * barsInAngle)) * 180 / M_PI;
    return angle;
}

//+------------------------------------------------------------------+
//| اعتبارسنجی خط روند
//+------------------------------------------------------------------+
bool CTrendLineDetector::ValidateTrendline(const TrendLine &line)
{
    // بررسی زاویه
    if(!IsLineValidByAngle(line))
        return false;
    
    // بررسی تعداد تماس‌ها
    if(!IsLineValidByTouches(line))
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| بررسی زاویه خط
//+------------------------------------------------------------------+
bool CTrendLineDetector::IsLineValidByAngle(const TrendLine &line)
{
    return (line.angle >= m_minTrendlineAngle);
}

//+------------------------------------------------------------------+
//| بررسی تعداد تماس‌های خط
//+------------------------------------------------------------------+
bool CTrendLineDetector::IsLineValidByTouches(const TrendLine &line)
{
    return (line.touchCount >= 2);
}

//+------------------------------------------------------------------+
//| محاسبه مقدار خط در یک کندل مشخص
//+------------------------------------------------------------------+
double CTrendLineDetector::CalculateLineValue(const TrendLine &line, int barShift)
{
    if(line.startBar == line.endBar) return line.startPrice;
    
    double pricePerBar = (line.endPrice - line.startPrice) / (line.endBar - line.startBar);
    double value = line.startPrice + (pricePerBar * (barShift - line.startBar));
    
    return value;
}

//+------------------------------------------------------------------+
//| شمارش تعداد تماس‌های قیمت با خط
//+------------------------------------------------------------------+
int CTrendLineDetector::CountTouchPoints(const TrendLine &line)
{
    int touches = 0;
    double tolerance = m_breakoutThreshold * 0.5; // نصف آستانه شکست
    
    for(int i = line.startBar; i <= line.endBar; i++)
    {
        double lineValue = CalculateLineValue(line, i);
        double high = iHigh(_Symbol, PERIOD_H4, i);
        double low = iLow(_Symbol, PERIOD_H4, i);
        double close = iClose(_Symbol, PERIOD_H4, i);
        
        // بررسی تماس قیمت با خط
        if(line.isUpTrend)
        {
            // در روند صعودی، خط کف است
            if(MathAbs(low - lineValue) <= tolerance)
                touches++;
        }
        else
        {
            // در روند نزولی، خط سقف است
            if(MathAbs(high - lineValue) <= tolerance)
                touches++;
        }
    }
    
    return touches;
}

//+------------------------------------------------------------------+
//| تشخیص خطوط روند
//+------------------------------------------------------------------+
int CTrendLineDetector::DetectTrendlines()
{
    double highs[], lows[];
    int highBars[], lowBars[];
    
    m_totalTrendlines = 0;
    
    if(!FindSwingPoints(highs, lows, highBars, lowBars))
        return 0;
    
    int highCount = ArraySize(highs);
    int lowCount = ArraySize(lows);
    
    // تشخیص خطوط روند صعودی (اتصال دره‌ها)
    for(int i = 0; i < lowCount - 1; i++)
    {
        for(int j = i + 1; j < lowCount; j++)
        {
            if(lowBars[i] > lowBars[j]) continue; // باید به ترتیب زمانی باشند
            
            TrendLine line;
            line.startPrice = lows[i];
            line.endPrice = lows[j];
            line.startBar = lowBars[i];
            line.endBar = lowBars[j];
            line.isUpTrend = true;
            line.slope = (line.endPrice - line.startPrice) / (line.endBar - line.startBar);
            line.angle = CalculateAngle(line.startPrice, line.endPrice, line.endBar - line.startBar);
            line.touchCount = CountTouchPoints(line);
            line.trendlineName = "TL_Up_" + IntegerToString(m_totalTrendlines);
            line.currentValue = CalculateLineValue(line, 0);
            
            if(ValidateTrendline(line))
            {
                if(m_totalTrendlines < 20)
                {
                    m_trendlines[m_totalTrendlines] = line;
                    m_totalTrendlines++;
                }
            }
        }
    }
    
    // تشخیص خطوط روند نزولی (اتصال قله‌ها)
    for(int i = 0; i < highCount - 1; i++)
    {
        for(int j = i + 1; j < highCount; j++)
        {
            if(highBars[i] > highBars[j]) continue;
            
            TrendLine line;
            line.startPrice = highs[i];
            line.endPrice = highs[j];
            line.startBar = highBars[i];
            line.endBar = highBars[j];
            line.isUpTrend = false;
            line.slope = (line.endPrice - line.startPrice) / (line.endBar - line.startBar);
            line.angle = CalculateAngle(line.startPrice, line.endPrice, line.endBar - line.startBar);
            line.touchCount = CountTouchPoints(line);
            line.trendlineName = "TL_Down_" + IntegerToString(m_totalTrendlines);
            line.currentValue = CalculateLineValue(line, 0);
            
            if(ValidateTrendline(line))
            {
                if(m_totalTrendlines < 20)
                {
                    m_trendlines[m_totalTrendlines] = line;
                    m_totalTrendlines++;
                }
            }
        }
    }
    
    // رسم خطوط در صورت فعال بودن
    if(m_drawTrendlines)
        DrawTrendlines();
    
    return m_totalTrendlines;
}

//+------------------------------------------------------------------+
//| بررسی افزایش حجم برای تأیید شکست
//+------------------------------------------------------------------+
bool CTrendLineDetector::CheckVolumeSpike(int index)
{
    double currentVolume = iVolume(_Symbol, PERIOD_H4, index);
    double avgVolume = 0;
    int avgPeriod = 20;
    
    // محاسبه میانگین حجم
    for(int i = index + 1; i <= index + avgPeriod; i++)
    {
        avgVolume += iVolume(_Symbol, PERIOD_H4, i);
    }
    avgVolume /= avgPeriod;
    
    if(avgVolume == 0) return false;
    
    return (currentVolume / avgVolume >= m_volumeSpikeFactor);
}

//+------------------------------------------------------------------+
//| بررسی شکست خط روند
//+------------------------------------------------------------------+
bool CTrendLineDetector::CheckBreakout(const TrendLine &line, bool isUptrend, double &breakPrice)
{
    // برای خط روند صعودی، شکست به پایین
    // برای خط روند نزولی، شکست به بالا
    bool breakout = false;
    breakPrice = 0;
    
    double currentLineValue = CalculateLineValue(line, 0);
    double close0 = iClose(_Symbol, PERIOD_H4, 0);
    double close1 = iClose(_Symbol, PERIOD_H4, 1);
    double close2 = iClose(_Symbol, PERIOD_H4, 2);
    
    if(isUptrend)
    {
        // شکست خط روند صعودی به پایین
        if(close0 < currentLineValue - m_breakoutThreshold)
        {
            // بررسی تعداد کندل‌های تأیید
            int confirmCount = 0;
            for(int i = 0; i < m_breakoutConfirmationBars; i++)
            {
                double lineValue = CalculateLineValue(line, i);
                if(iClose(_Symbol, PERIOD_H4, i) < lineValue - m_breakoutThreshold)
                    confirmCount++;
            }
            
            if(confirmCount >= m_breakoutConfirmationBars)
            {
                breakout = true;
                breakPrice = currentLineValue;
            }
        }
    }
    else
    {
        // شکست خط روند نزولی به بالا
        if(close0 > currentLineValue + m_breakoutThreshold)
        {
            int confirmCount = 0;
            for(int i = 0; i < m_breakoutConfirmationBars; i++)
            {
                double lineValue = CalculateLineValue(line, i);
                if(iClose(_Symbol, PERIOD_H4, i) > lineValue + m_breakoutThreshold)
                    confirmCount++;
            }
            
            if(confirmCount >= m_breakoutConfirmationBars)
            {
                breakout = true;
                breakPrice = currentLineValue;
            }
        }
    }
    
    // بررسی افزایش حجم
    if(breakout)
    {
        if(!CheckVolumeSpike(0))
        {
            // اگر حجم افزایش نداشته باشد، شکست ضعیف محسوب می‌شود
            // اما می‌توانیم با اخطار قبول کنیم
            Print("Warning: Breakout without volume spike");
        }
    }
    
    return breakout;
}

//+------------------------------------------------------------------+
//| بررسی شکست تمام خطوط
//+------------------------------------------------------------------+
int CTrendLineDetector::CheckBreakouts(bool &isBuy, double &breakPrice, int &brokenIndex)
{
    int breakoutCount = 0;
    isBuy = false;
    breakPrice = 0;
    brokenIndex = -1;
    
    for(int i = 0; i < m_totalTrendlines; i++)
    {
        double price;
        bool isBroken = CheckBreakout(m_trendlines[i], m_trendlines[i].isUpTrend, price);
        
        if(isBroken)
        {
            breakoutCount++;
            brokenIndex = i;
            m_trendlines[i].lastBreakTime = TimeCurrent();
            
            // شکست خط روند صعودی = سیگنال فروش (نه خرید)
            // شکست خط روند نزولی = سیگنال خرید
            if(m_trendlines[i].isUpTrend)
                isBuy = false;  // شکست خط صعودی = فروش
            else
                isBuy = true;   // شکست خط نزولی = خرید
                
            breakPrice = price;
            
            Print("Breakout detected on ", m_trendlines[i].trendlineName, 
                  " Price: ", DoubleToString(breakPrice, _Digits),
                  " Direction: ", isBuy ? "BUY" : "SELL");
        }
    }
    
    return breakoutCount;
}

//+------------------------------------------------------------------+
//| دریافت خط روند
//+------------------------------------------------------------------+
bool CTrendLineDetector::GetTrendline(int index, TrendLine &line)
{
    if(index >= 0 && index < m_totalTrendlines)
    {
        line = m_trendlines[index];
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| به‌روزرسانی مقادیر جاری خطوط
//+------------------------------------------------------------------+
void CTrendLineDetector::UpdateCurrentValues()
{
    for(int i = 0; i < m_totalTrendlines; i++)
    {
        m_trendlines[i].currentValue = CalculateLineValue(m_trendlines[i], 0);
    }
}

//+------------------------------------------------------------------+
//| دریافت مقدار جاری خط
//+------------------------------------------------------------------+
double CTrendLineDetector::GetCurrentLineValue(int index)
{
    if(index >= 0 && index < m_totalTrendlines)
    {
        return CalculateLineValue(m_trendlines[index], 0);
    }
    return 0;
}

//+------------------------------------------------------------------+
//| بررسی بالای خط بودن قیمت
//+------------------------------------------------------------------+
bool CTrendLineDetector::IsPriceAboveLine(int index, double price)
{
    if(index >= 0 && index < m_totalTrendlines)
    {
        double lineValue = GetCurrentLineValue(index);
        return (price > lineValue);
    }
    return false;
}

//+------------------------------------------------------------------+
//| بررسی پایین خط بودن قیمت
//+------------------------------------------------------------------+
bool CTrendLineDetector::IsPriceBelowLine(int index, double price)
{
    if(index >= 0 && index < m_totalTrendlines)
    {
        double lineValue = GetCurrentLineValue(index);
        return (price < lineValue);
    }
    return false;
}

//+------------------------------------------------------------------+
//| پاک کردن اشیاء گرافیکی
//+------------------------------------------------------------------+
void CTrendLineDetector::ClearObjects()
{
    ObjectsDeleteAll(0, "TL_");
    ObjectsDeleteAll(0, "Zone_");
}

//+------------------------------------------------------------------+
//| رسم خطوط روند
//+------------------------------------------------------------------+
void CTrendLineDetector::DrawTrendlines()
{
    if(!m_drawTrendlines) return;
    
    for(int i = 0; i < m_totalTrendlines; i++)
    {
        string objName = m_trendlines[i].trendlineName;
        
        // حذف خط قدیمی
        ObjectDelete(0, objName);
        
        // ایجاد خط جدید
        datetime time1 = iTime(_Symbol, PERIOD_H4, m_trendlines[i].startBar);
        datetime time2 = iTime(_Symbol, PERIOD_H4, m_trendlines[i].endBar);
        
        if(!ObjectCreate(0, objName, OBJ_TREND, 0, time1, m_trendlines[i].startPrice, time2, m_trendlines[i].endPrice))
        {
            Print("Failed to draw trendline: ", objName);
            continue;
        }
        
        // تنظیمات ظاهری
        ObjectSetInteger(0, objName, OBJPROP_COLOR, m_trendlines[i].isUpTrend ? m_uptrendColor : m_downtrendColor);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
        
        // اضافه کردن برچسب
        string labelName = objName + "_Label";
        ObjectDelete(0, labelName);
        
        ObjectCreate(0, labelName, OBJ_TEXT, 0, time2, m_trendlines[i].endPrice);
        ObjectSetString(0, labelName, OBJPROP_TEXT, "  " + DoubleToString(m_trendlines[i].angle, 1) + "°");
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, m_trendlines[i].isUpTrend ? m_uptrendColor : m_downtrendColor);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    }
}

//+------------------------------------------------------------------+
//| پایان کلاس CTrendLineDetector
//+------------------------------------------------------------------+