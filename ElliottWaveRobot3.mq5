//+------------------------------------------------------------------+
//|                                             ElliottWaveRobot.mq5 |
//|                                      Version 1.0 - Professional  |
//+------------------------------------------------------------------+
#property copyright "Elliott Wave Robot"
#property version   "1.00"
#property description "ربات معامله‌گر بر اساس امواج الیوت"
#property description "تشخیص خودکار ساختار 5 موجی + فیلتر فیبوناچی و استوکستیک"

//+------------------------------------------------------------------+
//| پارامترهای ورودی                                                 |
//+------------------------------------------------------------------+
//--- پارامترهای ZigZag
input int InpZigZagDepth = 12;        // عمق ZigZag
input int InpZigZagDeviation = 5;     // انحراف
input int InpZigZagBackstep = 3;      // گام برگشت

//--- پارامترهای امواج الیوت
input double InpWave2MaxRetrace = 0.786;  // حداکثر ریتریس موج 2
input double InpWave4MaxRetrace = 0.500;  // حداکثر ریتریس موج 4
input double InpWave3MinLength = 1.618;   // حداقل نسبت موج 3 به موج 1
input double InpFibTakeProfit = 0.618;    // حد سود فیبوناچی

//--- پارامترهای استوکستیک
input int InpStochK = 5;              // دوره %K
input int InpStochD = 3;              // دوره %D
input int InpStochSlow = 3;           // اسلوینگ
input int InpStochOversold = 20;      // اشباع فروش
input int InpStochOverbought = 80;    // اشباع خرید

//--- مدیریت ریسک
input double InpLotSize = 0.01;       // حجم معامله
input double InpRiskPercent = 2.0;    // درصد ریسک
input int InpStopLossPips = 200;      // حد ضرر ثابت (پیپ)
input int InpTakeProfitPips = 400;    // حد سود ثابت (پیپ)
input bool InpUseTrailing = true;     // استفاده از تریلینگ استاپ
input int InpTrailStart = 148;        // شروع تریلینگ (پیپ)
input int InpTrailStop = 100;         // فاصله تریلینگ (پیپ)

//--- محدودیت‌های معاملاتی
input int InpMaxOrdersPerDay = 2;     // حداکثر معامله در روز
input int InpMinTimeGap = 30;         // حداقل فاصله بین معاملات (دقیقه)
input bool InpAllowBuy = true;        // مجوز خرید
input bool InpAllowSell = true;       // مجوز فروش

//--- پارامترهای نمایش
input bool InpShowLabels = true;      // نمایش برچسب‌ها روی چارت
input color InpBullColor = clrBlue;   // رنگ موج صعودی
input color InpBearColor = clrRed;    // رنگ موج نزولی

//+------------------------------------------------------------------+
//| ساختار ذخیره‌سازی نقاط ZigZag                                    |
//+------------------------------------------------------------------+
struct ZigZagPoint
{
   datetime time;
   double price;
   int index;
   bool isHigh;
};

//+------------------------------------------------------------------+
//| ساختار ذخیره‌سازی امواج الیوت                                   |
//+------------------------------------------------------------------+
struct ElliottWave
{
   int waveNumber;        // شماره موج (1-5)
   double startPrice;     // قیمت شروع
   double endPrice;       // قیمت پایان
   datetime startTime;    // زمان شروع
   datetime endTime;      // زمان پایان
   bool isBullish;        // صعودی یا نزولی
   bool isValid;          // معتبر بودن
};

//+------------------------------------------------------------------+
//| کلاس اصلی ربات                                                  |
//+------------------------------------------------------------------+
class CElliottWaveRobot
{
private:
   //--- اندیکاتورها
   int m_zigzagHandle;
   int m_stochHandle;
   
   //--- ذخیره‌سازهای داده
   ZigZagPoint m_zigzagPoints[];
   ElliottWave m_waves[5];
   
   //--- متغیرهای مدیریتی
   int m_ordersToday;
   datetime m_lastTradeTime;
   long m_chartID;
   
   //--- متدهای خصوصی
   bool InitIndicators();
   void UpdateZigZagPoints();
   bool DetectElliottWaves();
   double CalculateWaveRatio(int wave1, int wave2);
   double CalculateRetracement(int waveA, int waveB);
   bool ValidateWaveRules();
   bool CheckStochFilter(bool isBuy);
   double CalculateDynamicStopLoss(bool isBuy);
   double CalculateDynamicTakeProfit(bool isBuy);
   bool IsTradingAllowed();
   void DrawWaveLabels();
   void DrawInvalidationLevel();
   void SendNotification(string message);
   
public:
   //--- سازنده و مخرب
   CElliottWaveRobot();
   ~CElliottWaveRobot();
   
   //--- متدهای عمومی
   bool Init();
   void Deinit();
   void Process();
   void OnTick();
};

//+------------------------------------------------------------------+
//| سازنده                                                           |
//+------------------------------------------------------------------+
CElliottWaveRobot::CElliottWaveRobot()
{
   m_zigzagHandle = INVALID_HANDLE;
   m_stochHandle = INVALID_HANDLE;
   m_ordersToday = 0;
   m_lastTradeTime = 0;
   m_chartID = ChartID();
   ArrayResize(m_zigzagPoints, 0);
}

//+------------------------------------------------------------------+
//| مخرب                                                            |
//+------------------------------------------------------------------+
CElliottWaveRobot::~CElliottWaveRobot()
{
   if(m_zigzagHandle != INVALID_HANDLE)
      IndicatorRelease(m_zigzagHandle);
   if(m_stochHandle != INVALID_HANDLE)
      IndicatorRelease(m_stochHandle);
}

//+------------------------------------------------------------------+
//| مقداردهی اولیه                                                  |
//+------------------------------------------------------------------+
bool CElliottWaveRobot::Init()
{
   return InitIndicators();
}

//+------------------------------------------------------------------+
//| مقداردهی اندیکاتورها                                            |
//+------------------------------------------------------------------+
bool CElliottWaveRobot::InitIndicators()
{
   //--- ZigZag
   m_zigzagHandle = iCustom(_Symbol, _Period, "Examples\\ZigZag",
                           InpZigZagDepth,
                           InpZigZagDeviation,
                           InpZigZagBackstep);
   
   if(m_zigzagHandle == INVALID_HANDLE)
      return false;
   
   //--- Stochastic
   m_stochHandle = iStochastic(_Symbol, _Period,
                              InpStochK, InpStochD, InpStochSlow,
                              MODE_SMA, STO_LOWHIGH);
   
   return (m_stochHandle != INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| به‌روزرسانی نقاط ZigZag                                         |
//+------------------------------------------------------------------+
void CElliottWaveRobot::UpdateZigZagPoints()
{
   double zigzagBuffer[];
   ArraySetAsSeries(zigzagBuffer, true);
   
   CopyBuffer(m_zigzagHandle, 0, 0, 100, zigzagBuffer);
   
   ArrayResize(m_zigzagPoints, 0);
   int pointIndex = 0;
   
   for(int i = 1; i < 100; i++)
   {
      if(zigzagBuffer[i] != 0 && zigzagBuffer[i] != EMPTY_VALUE)
      {
         ZigZagPoint point;
         point.time = iTime(_Symbol, _Period, i);
         point.price = zigzagBuffer[i];
         point.index = i;
         point.isHigh = (zigzagBuffer[i] > zigzagBuffer[i+1]);
         
         ArrayResize(m_zigzagPoints, pointIndex + 1);
         m_zigzagPoints[pointIndex] = point;
         pointIndex++;
      }
   }
}

//+------------------------------------------------------------------+
//| تشخیص امواج الیوت                                               |
//+------------------------------------------------------------------+
bool CElliottWaveRobot::DetectElliottWaves()
{
   if(ArraySize(m_zigzagPoints) < 6)
      return false;
   
   //--- تشخیص ساختار 5 موجی
   bool isBullishWave = (m_zigzagPoints[0].price < m_zigzagPoints[2].price);
   
   for(int i = 0; i < 5; i++)
   {
      if(i * 2 >= ArraySize(m_zigzagPoints) - 1)
         return false;
         
      m_waves[i].waveNumber = i + 1;
      m_waves[i].startPrice = m_zigzagPoints[i * 2].price;
      m_waves[i].endPrice = m_zigzagPoints[i * 2 + 1].price;
      m_waves[i].startTime = m_zigzagPoints[i * 2].time;
      m_waves[i].endTime = m_zigzagPoints[i * 2 + 1].time;
      m_waves[i].isBullish = isBullishWave;
   }
   
   return ValidateWaveRules();
}

//+------------------------------------------------------------------+
//| اعتبارسنجی قوانین امواج الیوت                                  |
//+------------------------------------------------------------------+
bool CElliottWaveRobot::ValidateWaveRules()
{
   //--- قانون 1: موج 2 نباید کل موج 1 را بازگشت بزند
   double retrace2 = CalculateRetracement(0, 1);
   if(retrace2 >= 1.0)
      return false;
   
   //--- قانون 2: موج 3 کوتاه‌ترین موج نباشد
   double wave1Length = MathAbs(m_waves[0].endPrice - m_waves[0].startPrice);
   double wave2Length = MathAbs(m_waves[1].endPrice - m_waves[1].startPrice);
   double wave3Length = MathAbs(m_waves[2].endPrice - m_waves[2].startPrice);
   
   if(wave3Length < wave1Length || wave3Length < wave2Length)
      return false;
   
   //--- قانون 3: موج 4 با محدوده موج 1 همپوشانی نداشته باشد
   if(m_waves[0].isBullish)
   {
      if(m_waves[3].endPrice <= m_waves[0].endPrice)
         return false;
   }
   else
   {
      if(m_waves[3].endPrice >= m_waves[0].endPrice)
         return false;
   }
   
   //--- بررسی نسبت موج 3 به موج 1
   double ratio31 = wave3Length / wave1Length;
   if(ratio31 < InpWave3MinLength)
      return false;
   
   //--- بررسی حداکثر ریتریس موج 2
   if(retrace2 > InpWave2MaxRetrace)
      return false;
   
   //--- بررسی حداکثر ریتریس موج 4
   double retrace4 = CalculateRetracement(2, 3);
   if(retrace4 > InpWave4MaxRetrace)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| محاسبه نسبت بین دو موج                                          |
//+------------------------------------------------------------------+
double CElliottWaveRobot::CalculateWaveRatio(int wave1, int wave2)
{
   double length1 = MathAbs(m_waves[wave1].endPrice - m_waves[wave1].startPrice);
   double length2 = MathAbs(m_waves[wave2].endPrice - m_waves[wave2].startPrice);
   
   if(length1 == 0)
      return 0;
      
   return length2 / length1;
}

//+------------------------------------------------------------------+
//| محاسبه درصد ریتریس                                              |
//+------------------------------------------------------------------+
double CElliottWaveRobot::CalculateRetracement(int waveA, int waveB)
{
   double moveLength = MathAbs(m_waves[waveA].endPrice - m_waves[waveA].startPrice);
   double retraceLength = MathAbs(m_waves[waveB].endPrice - m_waves[waveA].endPrice);
   
   if(moveLength == 0)
      return 0;
      
   return retraceLength / moveLength;
}

//+------------------------------------------------------------------+
//| بررسی فیلتر استوکستیک                                          |
//+------------------------------------------------------------------+
bool CElliottWaveRobot::CheckStochFilter(bool isBuy)
{
   double stochMain[], stochSignal[];
   ArraySetAsSeries(stochMain, true);
   ArraySetAsSeries(stochSignal, true);
   
   CopyBuffer(m_stochHandle, 0, 0, 3, stochMain);
   CopyBuffer(m_stochHandle, 1, 0, 3, stochSignal);
   
   if(isBuy)
   {
      //--- خرید: استوکستیک باید زیر اشباع فروش باشه
      return (stochMain[0] < InpStochOversold || 
              stochSignal[0] < InpStochOversold);
   }
   else
   {
      //--- فروش: استوکستیک باید بالای اشباع خرید باشه
      return (stochMain[0] > InpStochOverbought || 
              stochSignal[0] > InpStochOverbought);
   }
}

//+------------------------------------------------------------------+
//| محاسبه حد ضرر پویا                                             |
//+------------------------------------------------------------------+
double CElliottWaveRobot::CalculateDynamicStopLoss(bool isBuy)
{
   if(!m_waves[0].isValid)
      return SymbolInfoDouble(_Symbol, SYMBOL_BID) + 
             (isBuy ? -InpStopLossPips * _Point * 10 : InpStopLossPips * _Point * 10);
   
   //--- حد ضرر پایین‌تر از انتهای موج 1
   if(isBuy)
      return m_waves[0].startPrice - (InpStopLossPips * _Point * 10);
   else
      return m_waves[0].startPrice + (InpStopLossPips * _Point * 10);
}

//+------------------------------------------------------------------+
//| محاسبه حد سود پویا بر اساس فیبوناچی                            |
//+------------------------------------------------------------------+
double CElliottWaveRobot::CalculateDynamicTakeProfit(bool isBuy)
{
   if(!m_waves[2].isValid)
      return SymbolInfoDouble(_Symbol, SYMBOL_BID) + 
             (isBuy ? InpTakeProfitPips * _Point * 10 : -InpTakeProfitPips * _Point * 10);
   
   double wave1Length = MathAbs(m_waves[0].endPrice - m_waves[0].startPrice);
   double wave3Length = MathAbs(m_waves[2].endPrice - m_waves[2].startPrice);
   double projectLength = wave1Length * InpFibTakeProfit;
   
   if(isBuy)
      return m_waves[4].endPrice + projectLength;
   else
      return m_waves[4].endPrice - projectLength;
}

//+------------------------------------------------------------------+
//| بررسی محدودیت‌های معاملاتی                                      |
//+------------------------------------------------------------------+
bool CElliottWaveRobot::IsTradingAllowed()
{
   //--- محدودیت تعداد معاملات روزانه
   if(m_ordersToday >= InpMaxOrdersPerDay)
      return false;
   
   //--- محدودیت فاصله زمانی
   if(TimeCurrent() - m_lastTradeTime < InpMinTimeGap * 60)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| نمایش برچسب‌های امواج روی چارت                                 |
//+------------------------------------------------------------------+
void CElliottWaveRobot::DrawWaveLabels()
{
   if(!InpShowLabels)
      return;
      
   string objName;
   color waveColor;
   
   for(int i = 0; i < 5; i++)
   {
      if(!m_waves[i].isValid)
         continue;
      
      objName = "WAVE_" + IntegerToString(i + 1);
      waveColor = m_waves[i].isBullish ? InpBullColor : InpBearColor;
      
      //--- حذف آبجکت قدیمی
      ObjectDelete(m_chartID, objName);
      
      //--- ایجاد برچسب جدید
      ObjectCreate(m_chartID, objName, OBJ_TEXT, 0, 
                  m_waves[i].endTime, m_waves[i].endPrice);
      ObjectSetString(m_chartID, objName, OBJPROP_TEXT, 
                     IntegerToString(i + 1));
      ObjectSetInteger(m_chartID, objName, OBJPROP_COLOR, waveColor);
      ObjectSetInteger(m_chartID, objName, OBJPROP_FONTSIZE, 14);
      ObjectSetInteger(m_chartID, objName, OBJPROP_BACK, false);
   }
}

//+------------------------------------------------------------------+
//| نمایش سطح ابطال سناریو                                          |
//+------------------------------------------------------------------+
void CElliottWaveRobot::DrawInvalidationLevel()
{
   if(!m_waves[0].isValid)
      return;
      
   string objName = "INVALID_LEVEL";
   ObjectDelete(m_chartID, objName);
   
   double level;
   
   if(m_waves[0].isBullish)
      level = m_waves[0].startPrice;  // موج 1 در خرید
   else
      level = m_waves[0].startPrice;  // موج 1 در فروش
   
   ObjectCreate(m_chartID, objName, OBJ_HLINE, 0, 0, level);
   ObjectSetInteger(m_chartID, objName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(m_chartID, objName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(m_chartID, objName, OBJPROP_WIDTH, 1);
   ObjectSetString(m_chartID, objName, OBJPROP_TOOLTIP, "نقطه ابطال سناریوی الیوت");
}

//+------------------------------------------------------------------+
//| ارسال نوتیفیکیشن                                               |
//+------------------------------------------------------------------+
void CElliottWaveRobot::SendNotification(string message)
{
   string fullMessage = StringFormat("Elliott Wave Robot - %s: %s", 
                                    _Symbol, message);
   SendNotification(fullMessage);
   Print(fullMessage);
}

//+------------------------------------------------------------------+
//| پردازش اصلی روی تیک جدید                                        |
//+------------------------------------------------------------------+
void CElliottWaveRobot::OnTick()
{
   Process();
}

//+------------------------------------------------------------------+
//| فرآیند اصلی ربات                                                |
//+------------------------------------------------------------------+
void CElliottWaveRobot::Process()
{
   //--- به‌روزرسانی داده‌ها
   UpdateZigZagPoints();
   
   //--- تشخیص امواج
   bool newWavesDetected = DetectElliottWaves();
   
   if(newWavesDetected)
   {
      m_waves[0].isValid = true;
      m_waves[1].isValid = true;
      m_waves[2].isValid = true;
      m_waves[3].isValid = true;
      m_waves[4].isValid = true;
      
      //--- نمایش روی چارت
      DrawWaveLabels();
      DrawInvalidationLevel();
      
      //--- بررسی شرایط ورود
      if(!IsTradingAllowed())
         return;
      
      //--- سیگنال خرید
      if(InpAllowBuy && m_waves[0].isBullish)
      {
         if(CheckStochFilter(true))
         {
            double sl = CalculateDynamicStopLoss(true);
            double tp = CalculateDynamicTakeProfit(true);
            
            //--- ارسال سفارش خرید
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = InpLotSize;
            request.type = ORDER_TYPE_BUY;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            request.sl = sl;
            request.tp = tp;
            request.deviation = 10;
            request.comment = "Elliott Wave Buy - Wave 5";
            
            if(OrderSend(request, result))
            {
               if(result.retcode == TRADE_RETCODE_DONE)
               {
                  m_ordersToday++;
                  m_lastTradeTime = TimeCurrent();
                  SendNotification(StringFormat("خرید انجام شد - قیمت: %f", 
                                               request.price));
               }
            }
         }
      }
      
      //--- سیگنال فروش
      if(InpAllowSell && !m_waves[0].isBullish)
      {
         if(CheckStochFilter(false))
         {
            double sl = CalculateDynamicStopLoss(false);
            double tp = CalculateDynamicTakeProfit(false);
            
            //--- ارسال سفارش فروش
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.symbol = _Symbol;
            request.volume = InpLotSize;
            request.type = ORDER_TYPE_SELL;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            request.sl = sl;
            request.tp = tp;
            request.deviation = 10;
            request.comment = "Elliott Wave Sell - Wave 5";
            
            if(OrderSend(request, result))
            {
               if(result.retcode == TRADE_RETCODE_DONE)
               {
                  m_ordersToday++;
                  m_lastTradeTime = TimeCurrent();
                  SendNotification(StringFormat("فروش انجام شد - قیمت: %f", 
                                               request.price));
               }
            }
         }
      }
   }
   
   //--- مدیریت تریلینگ استاپ
   if(InpUseTrailing)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol)
               continue;
               
            if(PositionGetInteger(POSITION_MAGIC) != 0)
               continue;
               
            double currentSL = PositionGetDouble(POSITION_SL);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            int points = (int)((currentPrice - openPrice) / _Point / 10);
            
            if(points >= InpTrailStart)
            {
               double newSL;
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_SLTP;
               request.symbol = _Symbol;
               request.position = ticket;
               
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {
                  newSL = currentPrice - (InpTrailStop * _Point * 10);
                  if(newSL > currentSL)
                     request.sl = newSL;
               }
               else
               {
                  newSL = currentPrice + (InpTrailStop * _Point * 10);
                  if(newSL < currentSL || currentSL == 0)
                     request.sl = newSL;
               }
               
               if(request.sl != 0)
                  OrderSend(request, result);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| EA اصلی                                                          |
//+------------------------------------------------------------------+
CElliottWaveRobot *robot;

//+------------------------------------------------------------------+
//| تابع مقداردهی اولیه EA                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   robot = new CElliottWaveRobot();
   
   if(!robot.Init())
   {
      delete robot;
      return INIT_FAILED;
   }
   
   Print("ربات امواج الیوت با موفقیت راه‌اندازی شد");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| تابع Deinit                                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   delete robot;
   ObjectsDeleteAll(0, "WAVE_");
   ObjectsDeleteAll(0, "INVALID_LEVEL");
   Print("ربات امواج الیوت متوقف شد");
}

//+------------------------------------------------------------------+
//| تابع تیک جدید                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   if(robot != NULL)
      robot.OnTick();
}

//+------------------------------------------------------------------+
//| تابع مدیریت ترید                                                |
//+------------------------------------------------------------------+
void OnTrade()
{
   //--- به‌روزرسانی آمار معاملات روزانه
   if(robot != NULL)
   {
      //--- اینجا می‌تونی آمار معاملات رو آپدیت کنی
   }
}

//+------------------------------------------------------------------+