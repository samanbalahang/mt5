//+------------------------------------------------------------------+
//|                                                 SignalGenerator.mqh
//|                                     EURUSD Complete Breakout System v8.3
//+------------------------------------------------------------------+
#property copyright "EURUSD Complete Breakout System v8.3"
#property version "8.3"

//+------------------------------------------------------------------+
//| شامل کردن ساختارها و کلاس‌های مورد نیاز
//+------------------------------------------------------------------+
#include "Structures.mqh"
#include "IndicatorManager.mqh"
#include "TrendLineDetector.mqh"

//+------------------------------------------------------------------+
//| کلاس تولید و اعتبارسنجی سیگنال‌های معاملاتی
//+------------------------------------------------------------------+
class CSignalGenerator
{
private:
    // اشاره‌گر به کلاس‌های دیگر
    CIndicatorManager    *m_indicators;
    CTrendLineDetector   *m_trendLineDetector;
    
    // پارامترهای RSI
    int      m_rsiPeriod;
    double   m_rsiOverbought;
    double   m_rsiOversold;
    bool     m_useRSIConfirmation;
    int      m_rsiLookback;
    
    // پارامترهای تایید H1
    bool     m_useH1Confirmation;
    
    // سیگنال جاری
    TradeSignal m_currentSignal;
    
    // زمان آخرین بررسی
    datetime m_lastSignalTime;
    int      m_signalCooldownBars;  // تعداد کندل‌های انتظار بین سیگنال‌ها
    
    // متدهای خصوصی
    bool      CheckRSIConfirmation(bool isBuy, int shift = 0);
    bool      CheckRSIDivergence(bool isBullish, int lookback);
    bool      CheckH1Confirmation(bool isBuy, double breakPrice, double &confirmationPrice, datetime &confirmationTime);
    bool      CheckVolumeConfirmation(int shift = 0);
    bool      CheckMarketCondition();  // بررسی شرایط کلی بازار (روند، نوسان و...)
    bool      IsSignalCooldown();      // بررسی فاصله زمانی بین سیگنال‌ها
    double    CalculateSignalStrength(); // محاسبه قدرت سیگنال (0-100)
    
public:
    // سازنده و مخرب
    CSignalGenerator();
    ~CSignalGenerator();
    
    // مقداردهی اولیه
    void Initialize(CIndicatorManager *indicators, CTrendLineDetector *trendLineDetector);
    
    // تنظیم پارامترها
    void SetParameters(int rsiPeriod, double overbought, double oversold, 
                      bool useRSI, int rsiLookback, bool useH1);
    
    // تولید سیگنال بر اساس شکست خط روند
    bool GenerateSignalFromBreakout(bool isBuy, double breakPrice, int brokenTrendlineIndex);
    
    // اعتبارسنجی سیگنال با فیلترهای مختلف
    bool ValidateSignal(TradeSignal &signal);
    
    // دریافت سیگنال جاری
    TradeSignal GetCurrentSignal() { return m_currentSignal; }
    
    // ریست سیگنال
    void ResetSignal();
    
    // بررسی انقضای سیگنال
    bool IsSignalExpired(int maxWaitBars = 10);
    
    // دریافت قدرت سیگنال
    double GetSignalStrength() { return CalculateSignalStrength(); }
    
    // تنظیم زمان آخرین سیگنال
    void SetLastSignalTime(datetime time) { m_lastSignalTime = time; }
};

//+------------------------------------------------------------------+
//| سازنده کلاس
//+------------------------------------------------------------------+
CSignalGenerator::CSignalGenerator()
{
    // مقداردهی اولیه پارامترها
    m_rsiPeriod = 14;
    m_rsiOverbought = 65.0;
    m_rsiOversold = 35.0;
    m_useRSIConfirmation = true;
    m_rsiLookback = 20;
    m_useH1Confirmation = true;
    m_signalCooldownBars = 5;  // 5 کندل H4 = 20 ساعت
    
    // ریست سیگنال
    m_currentSignal.isValid = false;
    m_currentSignal.isBuy = false;
    m_currentSignal.h4_BreakPrice = 0;
    m_currentSignal.signalTime = 0;
    m_currentSignal.brokenTrendlineIndex = -1;
    
    m_lastSignalTime = 0;
    
    // ریست آرایه‌های TP
    for(int i = 0; i < 4; i++)
    {
        m_currentSignal.tpHit[i] = false;
        m_currentSignal.tpPercentages[i] = 0;
        m_currentSignal.fibonacciLevels[i] = 0;
    }
}

//+------------------------------------------------------------------+
//| مخرب کلاس
//+------------------------------------------------------------------+
CSignalGenerator::~CSignalGenerator()
{
    // اشاره‌گرها توسط کلاس اصلی مدیریت می‌شوند
}

//+------------------------------------------------------------------+
//| مقداردهی اولیه با اشاره‌گر به کلاس‌های دیگر
//+------------------------------------------------------------------+
void CSignalGenerator::Initialize(CIndicatorManager *indicators, CTrendLineDetector *trendLineDetector)
{
    m_indicators = indicators;
    m_trendLineDetector = trendLineDetector;
}

//+------------------------------------------------------------------+
//| تنظیم پارامترها
//+------------------------------------------------------------------+
void CSignalGenerator::SetParameters(int rsiPeriod, double overbought, double oversold, 
                                    bool useRSI, int rsiLookback, bool useH1)
{
    m_rsiPeriod = rsiPeriod;
    m_rsiOverbought = overbought;
    m_rsiOversold = oversold;
    m_useRSIConfirmation = useRSI;
    m_rsiLookback = rsiLookback;
    m_useH1Confirmation = useH1;
}

//+------------------------------------------------------------------+
//| بررسی تأیید RSI
//+------------------------------------------------------------------+
bool CSignalGenerator::CheckRSIConfirmation(bool isBuy, int shift = 0)
{
    if(!m_useRSIConfirmation) return true;
    if(m_indicators == NULL) return false;
    
    double rsiValue = m_indicators.GetRSI(PERIOD_H4, shift);
    if(rsiValue == 0) return false;
    
    if(isBuy)
    {
        // سیگنال خرید: RSI نباید در اشباع خرید باشد و ترجیحاً زیر 50 باشد
        if(rsiValue > m_rsiOverbought)
            return false;
            
        // بررسی واگرایی مثبت (صعودی)
        if(CheckRSIDivergence(true, m_rsiLookback))
            return true;
            
        // شرایط عادی
        return (rsiValue < 50.0);
    }
    else
    {
        // سیگنال فروش: RSI نباید در اشباع فروش باشد و ترجیحاً بالای 50 باشد
        if(rsiValue < m_rsiOversold)
            return false;
            
        // بررسی واگرایی منفی (نزولی)
        if(CheckRSIDivergence(false, m_rsiLookback))
            return true;
            
        // شرایط عادی
        return (rsiValue > 50.0);
    }
}

//+------------------------------------------------------------------+
//| بررسی واگرایی RSI
//+------------------------------------------------------------------+
bool CSignalGenerator::CheckRSIDivergence(bool isBullish, int lookback)
{
    if(m_indicators == NULL) return false;
    
    double price[], rsi[];
    ArrayResize(price, lookback);
    ArrayResize(rsi, lookback);
    
    // دریافت داده‌های قیمت و RSI
    for(int i = 0; i < lookback; i++)
    {
        if(isBullish)
            price[i] = iLow(_Symbol, PERIOD_H4, i);
        else
            price[i] = iHigh(_Symbol, PERIOD_H4, i);
            
        rsi[i] = m_indicators.GetRSI(PERIOD_H4, i);
    }
    
    if(isBullish)
    {
        // واگرایی مثبت: قیمت کف پایین‌تر، RSI کف بالاتر
        int low1 = ArrayMinimum(price, 0, lookback / 2);
        int low2 = ArrayMinimum(price, lookback / 2, lookback / 2);
        
        if(low1 > low2) // قیمت در low2 پایین‌تر است
        {
            double rsi1 = rsi[low1];
            double rsi2 = rsi[low2];
            
            if(rsi2 > rsi1) // RSI در low2 بالاتر است
                return true;
        }
    }
    else
    {
        // واگرایی منفی: قیمت قله بالاتر، RSI قله پایین‌تر
        int high1 = ArrayMaximum(price, 0, lookback / 2);
        int high2 = ArrayMaximum(price, lookback / 2, lookback / 2);
        
        if(high1 < high2) // قیمت در high2 بالاتر است
        {
            double rsi1 = rsi[high1];
            double rsi2 = rsi[high2];
            
            if(rsi2 < rsi1) // RSI در high2 پایین‌تر است
                return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| بررسی تأیید در تایم‌فریم H1
//+------------------------------------------------------------------+
bool CSignalGenerator::CheckH1Confirmation(bool isBuy, double breakPrice, 
                                          double &confirmationPrice, datetime &confirmationTime)
{
    if(!m_useH1Confirmation) 
    {
        confirmationPrice = breakPrice;
        confirmationTime = TimeCurrent();
        return true;
    }
    
    if(m_indicators == NULL) return false;
    
    // بررسی کندل H1 بعد از شکست
    datetime currentTime = TimeCurrent();
    int h1Shift = 0;
    bool confirmed = false;
    confirmationPrice = 0;
    confirmationTime = 0;
    
    // بررسی 3 کندل H1 اخیر
    for(int i = 0; i < 3; i++)
    {
        double h1High = iHigh(_Symbol, PERIOD_H1, i);
        double h1Low = iLow(_Symbol, PERIOD_H1, i);
        double h1Close = iClose(_Symbol, PERIOD_H1, i);
        double h1RSI = m_indicators.GetRSI(PERIOD_H1, i);
        
        if(isBuy) // سیگنال خرید - انتظار پولبک به خط روند شکسته شده
        {
            // خط روند نزولی شکسته شده، حالا قیمت باید بالای آن تثبیت شود
            if(h1Low > breakPrice && h1Close > breakPrice)
            {
                confirmed = true;
                confirmationPrice = h1Low;
                confirmationTime = iTime(_Symbol, PERIOD_H1, i);
                break;
            }
            
            // بررسی RSI برای تأیید قدرت
            if(h1RSI > 50 && h1RSI < 70)
            {
                confirmed = true;
                confirmationPrice = h1Low;
                confirmationTime = iTime(_Symbol, PERIOD_H1, i);
                break;
            }
        }
        else // سیگنال فروش
        {
            // خط روند صعودی شکسته شده، قیمت باید زیر آن تثبیت شود
            if(h1High < breakPrice && h1Close < breakPrice)
            {
                confirmed = true;
                confirmationPrice = h1High;
                confirmationTime = iTime(_Symbol, PERIOD_H1, i);
                break;
            }
            
            // بررسی RSI
            if(h1RSI < 50 && h1RSI > 30)
            {
                confirmed = true;
                confirmationPrice = h1High;
                confirmationTime = iTime(_Symbol, PERIOD_H1, i);
                break;
            }
        }
    }
    
    return confirmed;
}

//+------------------------------------------------------------------+
//| بررسی تأیید حجم
//+------------------------------------------------------------------+
bool CSignalGenerator::CheckVolumeConfirmation(int shift = 0)
{
    if(m_indicators == NULL) return false;
    
    double currentVolume = iVolume(_Symbol, PERIOD_H4, shift);
    double prevVolume = iVolume(_Symbol, PERIOD_H4, shift + 1);
    
    // حجم باید بیشتر از کندل قبل باشد
    if(currentVolume > prevVolume * 1.2) // 20% افزایش
        return true;
        
    return false;
}

//+------------------------------------------------------------------+
//| بررسی شرایط کلی بازار
//+------------------------------------------------------------------+
bool CSignalGenerator::CheckMarketCondition()
{
    // بررسی نوسان بازار با ATR
    double atr = m_indicators.GetATR(PERIOD_H4, 0);
    double atrPercent = (atr / iClose(_Symbol, PERIOD_H4, 0)) * 100;
    
    // اگر نوسان خیلی کم است (< 0.1%) معامله نکن
    if(atrPercent < 0.1)
        return false;
        
    // اگر نوسان خیلی زیاد است (> 2%) معامله نکن
    if(atrPercent > 2.0)
        return false;
    
    // بررسی زمان مناسب برای معامله (جلسات لندن و نیویورک)
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    int hour = dt.hour;
    
    // بهترین زمان: 8-17 لندن (ساعت سرور معمولا 2 ساعت جلوتر است)
    bool isTradingSession = (hour >= 8 && hour <= 17);
    
    // در صورت تمایل می‌توان این شرط را غیرفعال کرد
    // if(!isTradingSession) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| بررسی فاصله زمانی بین سیگنال‌ها
//+------------------------------------------------------------------+
bool CSignalGenerator::IsSignalCooldown()
{
    if(m_lastSignalTime == 0) return false;
    
    datetime currentTime = TimeCurrent();
    int barsPassed = Bars(_Symbol, PERIOD_H4, m_lastSignalTime, currentTime);
    
    return (barsPassed < m_signalCooldownBars);
}

//+------------------------------------------------------------------+
//| محاسبه قدرت سیگنال
//+------------------------------------------------------------------+
double CSignalGenerator::CalculateSignalStrength()
{
    if(!m_currentSignal.isValid) return 0;
    
    double strength = 50.0; // پایه 50
    
    // 1. قدرت شکست خط روند
    if(m_currentSignal.brokenTrendlineIndex >= 0)
    {
        TrendLine line;
        if(m_trendLineDetector.GetTrendline(m_currentSignal.brokenTrendlineIndex, line))
        {
            // خط با تماس‌های بیشتر = قوی‌تر
            strength += line.touchCount * 5;
            
            // زاویه مناسب (20-45 درجه) = قوی‌تر
            if(line.angle >= 20 && line.angle <= 45)
                strength += 10;
            else if(line.angle > 45) // خیلی تند = ضعیف‌تر
                strength -= 5;
        }
    }
    
    // 2. قدرت RSI
    double rsi = m_indicators.GetRSI(PERIOD_H4, 0);
    if(m_currentSignal.isBuy)
    {
        if(rsi < 40) strength += 15;
        else if(rsi < 50) strength += 10;
        else if(rsi > 60) strength -= 10;
    }
    else
    {
        if(rsi > 60) strength += 15;
        else if(rsi > 50) strength += 10;
        else if(rsi < 40) strength -= 10;
    }
    
    // 3. تأیید H1
    if(m_currentSignal.h1_ConfirmationPrice != 0)
        strength += 15;
    
    // 4. حجم
    if(CheckVolumeConfirmation())
        strength += 10;
    
    // محدود کردن بین 0 تا 100
    strength = MathMax(0, MathMin(100, strength));
    
    return strength;
}

//+------------------------------------------------------------------+
//| تولید سیگنال از شکست خط روند
//+------------------------------------------------------------------+
bool CSignalGenerator::GenerateSignalFromBreakout(bool isBuy, double breakPrice, int brokenTrendlineIndex)
{
    // بررسی فاصله زمانی
    if(IsSignalCooldown())
    {
        Print("Signal cooldown active. Last signal: ", TimeToString(m_lastSignalTime));
        return false;
    }
    
    // بررسی شرایط بازار
    if(!CheckMarketCondition())
    {
        Print("Market condition not suitable for trading");
        return false;
    }
    
    // ایجاد سیگنال جدید
    TradeSignal newSignal;
    newSignal.isValid = false;
    newSignal.isBuy = isBuy;
    newSignal.h4_BreakPrice = breakPrice;
    newSignal.signalTime = TimeCurrent();
    newSignal.brokenTrendlineIndex = brokenTrendlineIndex;
    newSignal.breakEvenActivated = false;
    newSignal.currentWave = 0;
    newSignal.trailingStop = 0;
    
    // تنظیم کندل ورود (کندل شکست)
    newSignal.entryCandleTime = iTime(_Symbol, PERIOD_H4, 0);
    newSignal.entryCandleHigh = iHigh(_Symbol, PERIOD_H4, 0);
    newSignal.entryCandleLow = iLow(_Symbol, PERIOD_H4, 0);
    newSignal.entryCandleClose = iClose(_Symbol, PERIOD_H4, 0);
    
    // 1. تأیید RSI
    if(!CheckRSIConfirmation(isBuy, 0))
    {
        Print("RSI confirmation failed");
        return false;
    }
    
    // 2. تأیید H1
    double confirmationPrice;
    datetime confirmationTime;
    if(!CheckH1Confirmation(isBuy, breakPrice, confirmationPrice, confirmationTime))
    {
        if(m_useH1Confirmation)
        {
            Print("H1 confirmation failed");
            return false;
        }
    }
    else
    {
        newSignal.h1_ConfirmationPrice = confirmationPrice;
        newSignal.h1_ConfirmationTime = confirmationTime;
    }
    
    // سیگنال معتبر است
    newSignal.isValid = true;
    m_currentSignal = newSignal;
    m_lastSignalTime = TimeCurrent();
    
    Print("Signal generated: ", isBuy ? "BUY" : "SELL", 
          " at price: ", DoubleToString(breakPrice, _Digits),
          " Strength: ", DoubleToString(CalculateSignalStrength(), 1), "%");
    
    return true;
}

//+------------------------------------------------------------------+
//| اعتبارسنجی سیگنال با تمام فیلترها
//+------------------------------------------------------------------+
bool CSignalGenerator::ValidateSignal(TradeSignal &signal)
{
    if(!signal.isValid) return false;
    
    // بررسی زمان سیگنال (نباید خیلی قدیمی باشد)
    if(IsSignalExpired(12)) // 12 کندل H4 = 48 ساعت
    {
        Print("Signal expired");
        signal.isValid = false;
        return false;
    }
    
    // بررسی مجدد RSI
    if(!CheckRSIConfirmation(signal.isBuy, 0))
    {
        Print("RSI validation failed");
        signal.isValid = false;
        return false;
    }
    
    // بررسی اینکه قیمت هنوز در ناحیه مناسبی است
    double currentPrice = iClose(_Symbol, PERIOD_H4, 0);
    double entryZone = (signal.isBuy ? 20 : -20) * _Point * 10; // 20 پیپ
    
    if(signal.isBuy)
    {
        if(currentPrice > signal.h4_BreakPrice + entryZone * 3) // خیلی دور شده
        {
            Print("Price moved too far from breakout point");
            signal.isValid = false;
            return false;
        }
    }
    else
    {
        if(currentPrice < signal.h4_BreakPrice - entryZone * 3)
        {
            Print("Price moved too far from breakout point");
            signal.isValid = false;
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| بررسی انقضای سیگنال
//+------------------------------------------------------------------+
bool CSignalGenerator::IsSignalExpired(int maxWaitBars = 10)
{
    if(!m_currentSignal.isValid) return true;
    if(m_currentSignal.signalTime == 0) return true;
    
    int barsPassed = Bars(_Symbol, PERIOD_H4, m_currentSignal.signalTime, TimeCurrent());
    
    return (barsPassed > maxWaitBars);
}

//+------------------------------------------------------------------+
//| ریست سیگنال
//+------------------------------------------------------------------+
void CSignalGenerator::ResetSignal()
{
    m_currentSignal.isValid = false;
    m_currentSignal.isBuy = false;
    m_currentSignal.h4_BreakPrice = 0;
    m_currentSignal.signalTime = 0;
    m_currentSignal.h1_ConfirmationPrice = 0;
    m_currentSignal.h1_ConfirmationTime = 0;
    m_currentSignal.brokenTrendlineIndex = -1;
    m_currentSignal.breakEvenActivated = false;
    m_currentSignal.currentWave = 0;
    m_currentSignal.trailingStop = 0;
    
    for(int i = 0; i < 4; i++)
    {
        m_currentSignal.tpHit[i] = false;
        m_currentSignal.tpLevels[i] = 0;
    }
}

//+------------------------------------------------------------------+
//| پایان کلاس CSignalGenerator
//+------------------------------------------------------------------+