//+------------------------------------------------------------------+
//|                                              JK_EWT_CHANNELS.mq4 |
//|                                Copyright 2005-2014, Jpnny Kelso. |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, Jonny Kelso."
#property description "Jonny Kelso's EWT indicator"
#property strict

//---- indicator settings
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Blue
//---- input parameters
input int CONST_EWT_PERIOD = 52;
//---- indicator buffers
double ExtHighBuffer[];
double ExtLowBuffer[];
int EWT_HIGH[10000];
int EWT_LOW[10000];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit(void)
  {
   IndicatorDigits(Digits);
//---- line shifts when drawing
   SetIndexShift(0,0);
   SetIndexShift(1,0);
//---- first positions skipped when drawing
   SetIndexDrawBegin(0,CONST_EWT_PERIOD);
   SetIndexDrawBegin(1,CONST_EWT_PERIOD);
//---- 3 indicator buffers mapping
   SetIndexBuffer(0,ExtHighBuffer);
   SetIndexBuffer(1,ExtLowBuffer);
//---- drawing settings
   SetIndexStyle(0,DRAW_LINE);
   SetIndexStyle(1,DRAW_LINE);
//---- index labels
   SetIndexLabel(0,"LEWT");
   SetIndexLabel(1,"SEWT");
  }
//+------------------------------------------------------------------+
//| Bill Williams' Alligator                                         |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    int limit = rates_total - prev_calculated;
    limit += 2;
    //Print("indicator limit = ",limit);
    if(limit > 1000){limit = 1000;}
    //---- main loop
    for(int bar = 0; bar < limit; bar++)
    {
        EWT_HIGH[bar]   =iHighest(NULL,Period(),MODE_HIGH,CONST_EWT_PERIOD,bar);
        EWT_LOW[bar]    =iLowest (NULL,Period(),MODE_LOW ,CONST_EWT_PERIOD,bar);
    }
    //EWT_HIGH[0]   =EWT_HIGH[1];
    //EWT_LOW[0]    =EWT_LOW[1];
    
    for(int i=0; i < limit; i++)
    {
        ExtHighBuffer[i]=High[EWT_HIGH[i]]; 
        ExtLowBuffer[i] = Low[ EWT_LOW[i]]; 
    }

    ChartRedraw();
    //---- done
    return(rates_total);
}
//+------------------------------------------------------------------+
