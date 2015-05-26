//+------------------------------------------------------------------+
//|                                                  UTPTrader_1.mq4 |
//|                                      Copyright 2015, Jonny Kelso |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Jonny Kelso"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <stderror.mqh>
#include <stdlib.mqh>
#include "Instrument.mqh"
#include "Trade.mqh"

const int CONST_MAX_PERIOD = 60;
const int CONST_SMS_PERIOD = 52;
const int CONST_EWT_PERIOD = 21;
const int CONST_NUM_SYMBOLS = 17;
string InstrsLogFilename = "UTP_InstrsLog.csv";
string DebugLogFilename = "UTP_DebugLog.csv";
string TradeLogFilename = "UTP_TradeLog.csv";
int InstrsLogHandle = -1;
int DebugLogHandle = -1;
int TradeLogHandle = -1;
// years worth of ewt indexes
int EWT_HIGH[365]; 
int EWT_LOW[365];
string point1_date = "";
string point2_date = "";
string point3_date = "";
string point4_date = "";
Instrument Instrs[17];


//                   Symbol 	    Base        Minimum Lot  	Pip         trade
//                                  Currency    Trade   Size    Location    tickets
//                                  Chart       Size
Instrument instr01("EURUSD",	    "GBPUSD",   0.01,	100000,	0.0001,     0,0,0,0);      //USD
Instrument instr02("GBPUSD",	    "GBPUSD",   0.01,	100000,	0.0001,     0,0,0,0);      //USD
Instrument instr03("EURCHF",	    "GBPCHF",   0.01,	100000,	0.0001,     0,0,0,0);      //CHF
Instrument instr04("USDJPY",       "GBPJPY",   0.01,	100000,	0.01,       0,0,0,0);        //JPY
Instrument instr05(".UK100",	    "GBP",      0.01,	1,	    1,          0,0,0,0);           //GBP
Instrument instr06(".US500",	    "GBPUSD",   0.01,	1,	    1,          0,0,0,0);           //USD
Instrument instr07("XAUUSD",	    "GBPUSD",   0.01,	100,    0.01,       0,0,0,0);        //USD
Instrument instr08("USCotton",	    "GBPUSD",   0.01,	10000,	0.01,       0,0,0,0);        //USD
Instrument instr09("USSugar",	    "GBPUSD",   0.01,	10000,	0.01,       0,0,0,0);        //USD
Instrument instr10("WTICrude",	    "GBPUSD",   0.01,	100,    0.01,       0,0,0,0);        //USD
Instrument instr11("NaturalGas",	"GBPUSD",   0.01,	1000,	0.001,      0,0,0,0);       //USD
Instrument instr12("FACE",	        "GBPUSD",   1,	    1,	    0.01,       0,0,0,0);        //USD
Instrument instr13("GOOG",	        "GBPUSD",   1,	    1,  	0.01,       0,0,0,0);        //USD
Instrument instr14("MSFT",	        "GBPUSD",   1,	    1,	    0.01,       0,0,0,0);        //USD
Instrument instr15("TWTR",	        "GBPUSD",   1,	    1,	    0.01,       0,0,0,0);        //USD
Instrument instr16("USTNote",	    "GBPUSD",   1,	    100,    0.01,       0,0,0,0);        //USD
Instrument instr17("YHOO",	        "GBPUSD",   1,	    1,	    0.01,       0,0,0,0);        //USD


//+--------------------------------------------------------------------------------------------------------------------+
void PrintMsg(int hndl,string msg)
{
    if(hndl > -1)
    {
        msg = msg + "\n";
        FileWriteString(hndl,msg,256);    
    }
}
//+--------------------------------------------------------------------------------------------------------------------+
void BuildInstrumentList()
{    
    PrintMsg(DebugLogHandle,"BuildInstrumentList called");

    InstrumentCopy(Instrs[0],instr01);
    InstrumentCopy(Instrs[1],instr02);
    InstrumentCopy(Instrs[2],instr03);
    InstrumentCopy(Instrs[3],instr04);
    InstrumentCopy(Instrs[4],instr05);
    InstrumentCopy(Instrs[5],instr06);
    InstrumentCopy(Instrs[6],instr07);
    InstrumentCopy(Instrs[7],instr08);
    InstrumentCopy(Instrs[8],instr09);
    InstrumentCopy(Instrs[9],instr10);
    InstrumentCopy(Instrs[10],instr11);
    InstrumentCopy(Instrs[11],instr12);
    InstrumentCopy(Instrs[12],instr13);
    InstrumentCopy(Instrs[13],instr14);
    InstrumentCopy(Instrs[14],instr15);
    InstrumentCopy(Instrs[15],instr16);
    InstrumentCopy(Instrs[16],instr17);
    
    PrintMsg(DebugLogHandle,"BuildInstrumentList returned");

}
//+--------------------------------------------------------------------------------------------------------------------+
void InstrumentCopy(Instrument &a, Instrument &b)
{
    a.symbol = b.symbol;
    a.base_currency_chart = b.base_currency_chart;
    a.min_trade_size = b.min_trade_size;
    a.lot_size = b.lot_size;
    a.pip_location = b.pip_location;
}
//+--------------------------------------------------------------------------------------------------------------------+
int ReadInstrsLog()
{
    PrintMsg(DebugLogHandle,"ReadInstrsLog called");
    InstrsLogHandle = -1;
    InstrsLogHandle=FileOpen(InstrsLogFilename,FILE_CSV|FILE_READ);  
    if(InstrsLogHandle > -1)
    {
        while(!FileIsEnding(InstrsLogHandle))
        {
            for(int index = 0; index < 17; index++)
            {
                string symbol_str = "";
            
                string line = FileReadString(InstrsLogHandle,1);
                string separator = ",";
                ushort sep = StringGetCharacter(separator,0);
                string strings[];
                int result = StringSplit(line,sep,strings);
                if(result > 0)
                {
                    Instrs[index].symbol = strings[0];
                    Instrs[index].base_currency_chart = strings[1];
                    Instrs[index].min_trade_size = StringToDouble(strings[2]);
                    Instrs[index].lot_size = StringToDouble(strings[3]);
                    Instrs[index].pip_location = StringToDouble(strings[4]);
                    Instrs[index].lsms_trade = (int)StringToInteger(strings[5]);
                    Instrs[index].lewt_trade = (int)StringToInteger(strings[6]);
                    Instrs[index].sewt_trade = (int)StringToInteger(strings[7]);
                    Instrs[index].ssms_trade = (int)StringToInteger(strings[8]);
                
                    PrintMsg(DebugLogHandle,StringFormat("Instrs[%d]=%s",index,Instrs[index].AsString()));
                    
                }
            }
            break;
        }
        FileClose(InstrsLogHandle);
        InstrsLogHandle = -1;
    }
    else
    {
        PrintMsg(DebugLogHandle,"ReadInstrsLog - Invalid file handle passed");
    }
    PrintMsg(DebugLogHandle,"ReadInstrsLog returned");
    return 0;
}
//+--------------------------------------------------------------------------------------------------------------------+
int WriteInstrsLog()
{
    PrintMsg(DebugLogHandle,"WriteInstrsLog called");
    if(InstrsLogHandle > -1)
    {
        FileClose(InstrsLogHandle);
        InstrsLogHandle = -1;
    }
    InstrsLogHandle=FileOpen(InstrsLogFilename,FILE_CSV|FILE_WRITE|FILE_ANSI);
    if(InstrsLogHandle == -1){ return 1; }
    
    for(int index = 0; index < 17; index++)
    {
        FileWriteString(InstrsLogHandle,Instrs[index].AsString());
    }
    FileClose(InstrsLogHandle);
    InstrsLogHandle = -1;
    
    PrintMsg(DebugLogHandle,"WriteInstrsLog returned");
    return 0;
}
//+--------------------------------------------------------------------------------------------------------------------+
int LogTrade(Trade &trade)
{
    PrintMsg(DebugLogHandle,StringFormat("LogTrade called with trade = %s",trade.AsString()));

    if(TradeLogHandle == -1)
    {
        TradeLogHandle=FileOpen(TradeLogFilename,FILE_CSV|FILE_WRITE|FILE_ANSI);
    }
    //ulong offset_bytes = FileSize(TradeLogHandle);
    
    FileSeek(TradeLogHandle,0,SEEK_END);
    FileWriteString(TradeLogHandle,StringFormat("%s",trade.AsString()));
    //FileClose(TradeLogHandle);
    //TradeLogHandle = -1;

    PrintMsg(DebugLogHandle,"LogTrade returned");

    return 0;
}
//+--------------------------------------------------------------------------------------------------------------------+
int CalculateLTCT(string symbol, bool &profit)
{
    PrintMsg(DebugLogHandle,StringFormat("CalculateLTCT called with %s",symbol));

    int error_status = 0;
    profit = false;
    string symb = symbol;

    CalculateEWTValues(symb);
    // get most recent ewt touch from today
    int lewt_bar = -1;
    int sewt_bar = -1;
    MostRecentEWTTouches(symb,0,lewt_bar,sewt_bar);
    bool MostRecentIsHigh = false;
    datetime date_time;
    int MN = -1; // Month         
    int DD = -1; // Day
    int HH = -1; // Hour
    if(lewt_bar > -1 && sewt_bar > -1)
    {
        
        int point_1_bar = -1;
        int point_2_bar = -1;
        if(lewt_bar > sewt_bar)
        {
            // most recent bar is 0, so sewt_bar touch is more recent than lewt_bar touch
            // *********** POINT 1 = sewt_bar
            
            point_1_bar = sewt_bar;
            MostRecentIsHigh = false;
            date_time = iTime(symb,PERIOD_D1,point_1_bar);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            point1_date = StringFormat("%2dM-%2dD_%2dH",MN,DD,HH);
            // *********** POINT 2 = lewt_bar
            point_2_bar = lewt_bar;
            date_time = iTime(symb,PERIOD_D1,point_2_bar);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            point2_date = StringFormat("%2dM-%2dD_%2dH",MN,DD,HH);
        }
        else
        {
            // lewt_bar touch is more recent than sewt_bar touch
            // *********** POINT 1 = lewt_bar
            point_1_bar = lewt_bar;
            MostRecentIsHigh = true;
            date_time = iTime(symb,PERIOD_D1,point_1_bar);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            point1_date = StringFormat("%2dM-%2dD_%2dH",MN,DD,HH);
            // *********** POINT 2 = sewt_bar
            point_2_bar = sewt_bar;
            date_time = iTime(symb,PERIOD_D1,point_2_bar);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            point2_date = StringFormat("%2dM-%2dD_%2dH",MN,DD,HH);
        }
    }
    else
    {
        PrintMsg(DebugLogHandle, "Error - Couldn't find both recent EWT touches");
        error_status = 1;
        return error_status;
    }
    

    int most_recent_opposite_touch = -1;
    int opposite_touch_is_high = -1;
    int opp_lewt_bar = -1;
    int opp_sewt_bar = -1;
    if (MostRecentIsHigh)
    {
        // most recent touch is on lewt.
        most_recent_opposite_touch = sewt_bar;
        opposite_touch_is_high = 0; //low
    }
    else
    {
        // most recent touch is on sewt.
        // get next most recent opposite touch
        most_recent_opposite_touch = lewt_bar;
        opposite_touch_is_high = 1; //high
    }
    
    int direction_change_index = FindIndexOfDirectionChangefromIndex(symb, most_recent_opposite_touch, opposite_touch_is_high);
    date_time = iTime(symb,PERIOD_D1,direction_change_index);
    MN=TimeMonth(date_time); // Month         
    DD=TimeDay(date_time);   // Day
    HH=TimeHour(date_time);  // Hour
    point3_date = StringFormat("%2dM-%2dD_%2dH",MN,DD,HH);
    // **************** (3) mark plot at high/low of index most_recent_opposite_touch depedning on opposite_touch_highlow
    if (direction_change_index > -1)
    {
        // Now get next recent touch of opposite ewt
        int lewt_index = -1;
        int sewt_index = -1;

        NextEWTTouchesForward(symb,(direction_change_index - 1),lewt_index,sewt_index);
        if (opposite_touch_is_high)
        {
            // direction change in high, found opposite touch in low.
            // **************** (4) mark plot at low of index sewt_index
            date_time = iTime(symb,PERIOD_D1,sewt_index);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            PrintMsg(DebugLogHandle,StringFormat("Next low ewt touch: bar=%d Date=%d-%d_%d",sewt_index,MN,DD,HH));
            point4_date = StringFormat("%2dM-%2dD_%2dH",MN,DD,HH);
            // we would have entered LONG at direction change in high, and exited at next ewt touch on opposite side
            // is there profit?
            double entry_val = iHigh(symb,PERIOD_D1,direction_change_index);
            double exit_val = iLow(symb,PERIOD_D1,sewt_index);
            if (exit_val > entry_val)
            {
                profit = true;
            }
            else
            {
                profit = false;
            }

        }
        else
        {
            // direction change in low, found opposite touch in high.
            // **************** (4) mark plot at high of index lewt_index
            date_time = iTime(symb,PERIOD_D1,lewt_index);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            PrintMsg(DebugLogHandle,StringFormat("Next low ewt touch: bar=%d Date=%d-%d_%d",lewt_index,MN,DD,HH));
            point4_date = StringFormat("%2dM-%2dD_%2dH",MN,DD,HH);
            // we would have entered SHORT at direction change in low, and exited at next ewt touch on opposite side
            // is there profit?
            double entry_val = iLow(symb,PERIOD_D1,direction_change_index);
            double exit_val = iHigh(symb,PERIOD_D1,lewt_index);
            if (exit_val < entry_val)
            {
                profit = true;
            }
            else
            {
                profit = false;
            }
        }
        PrintMsg(DebugLogHandle, StringFormat("Point 1 = %s",point1_date));
        PrintMsg(DebugLogHandle, StringFormat("Point 2 = %s",point2_date));
        PrintMsg(DebugLogHandle, StringFormat("Point 3 = %s",point3_date));
        PrintMsg(DebugLogHandle, StringFormat("Point 4 = %s",point4_date));
        PrintMsg(DebugLogHandle, StringFormat("%s LTCT is in %s",symbol,(profit ? "PROFIT" : "LOSS")));

    }
    else
    {
        PrintMsg(DebugLogHandle, "Couldn't detect direction change");
    }
   
    return 0;
}
//+--------------------------------------------------------------------------------------------------------------------+
int GetEWTIndexFromIndex(string symb, int start_index, int HighLow)
{
    PrintMsg(DebugLogHandle,StringFormat("GetEWTIndexFromIndex called with\n symbol=%s\n start_index=%d\n HighLow=%d",symb,start_index,HighLow));

    int ewt_index = -1;
    if (HighLow == 1)
    {
        ewt_index = iHighest(symb,PERIOD_D1,MODE_HIGH,CONST_EWT_PERIOD,start_index);
    }
    else
    {
        ewt_index = iLowest(symb,PERIOD_D1,MODE_LOW,CONST_EWT_PERIOD,start_index);
    }
    PrintMsg(DebugLogHandle,StringFormat("GetEWTIndexFromIndex returned with\n ewt_index=%d",ewt_index));

    return ewt_index;
}
//+--------------------------------------------------------------------------------------------------------------------+
double EWTValueAtIndex(string symbol, int start_index, int IsHigh)
{
    datetime date_time = iTime(symbol,PERIOD_D1,start_index);
    int MN=TimeMonth(date_time); // Month         
    int DD=TimeDay(date_time);   // Day
    int HH=TimeHour(date_time);  // Hour
    //PrintMsg(DebugLogHandle,StringFormat("Found a touch on low: bar=%d\n Date=%d-%d_%d",bar,MN,DD,HH));
            
    PrintMsg(DebugLogHandle,StringFormat("EWTValueAtIndex called with %s, point 2=%d, Date=%d-%d_%d, Ishigh=%d",symbol,start_index,MN,DD,HH,IsHigh));

    int ewt_index = -1;
    double ewt_value = 0.0;
    if (IsHigh ==1)
    {
        ewt_index = iHighest(symbol,PERIOD_D1,MODE_HIGH,CONST_EWT_PERIOD,start_index);
        ewt_value = iHigh(symbol,PERIOD_D1,ewt_index);
    }
    else
    {
        ewt_index = iLowest(symbol,PERIOD_D1,MODE_LOW,CONST_EWT_PERIOD,start_index);
        ewt_value = iLow(symbol,PERIOD_D1,ewt_index);
    }
    //PrintMsg(DebugLogHandle,StringFormat("EWTValueAtIndex returned ewt_value=%d",ewt_value));

    return ewt_value;
}
//+--------------------------------------------------------------------------------------------------------------------+
void CalculateEWTValues(string symbol)
{
    PrintMsg(DebugLogHandle,StringFormat("CalculateEWTValues called with symbol %s",symbol));
    
    //string highs = "";
    for (int bar = 0; bar < 365; bar++)
    {
        int ewt_index = -1;
        ewt_index = iHighest(symbol,PERIOD_D1,MODE_HIGH,CONST_EWT_PERIOD,bar);
        if(ewt_index > -1)
        {
            EWT_HIGH[bar]=ewt_index;
            //highs += StringFormat("[%d,%d]",bar,ewt_index);
        }
    }
    //PrintMsg(DebugLogHandle,StringFormat("CalculateEWTValues Highs = %s",highs));
    
    //string lows = "";
    for (int bar = 0; bar < 365; bar++)
    {
        int ewt_index = -1;
        ewt_index = iLowest(symbol,PERIOD_D1,MODE_LOW,CONST_EWT_PERIOD,bar);
        if(ewt_index > -1)
        {
            EWT_LOW[bar]=ewt_index;
            //lows += StringFormat("[%d,%d]",bar,ewt_index);
        }
    }
    //PrintMsg(DebugLogHandle,StringFormat("CalculateEWTValues Lows = %s",lows));


    PrintMsg(DebugLogHandle,"CalculateEWTValues returned");

}
//+--------------------------------------------------------------------------------------------------------------------+
void MostRecentEWTTouches(string symbol, int start_index, int& lewt_index, int& sewt_index)
{
    PrintMsg(DebugLogHandle,StringFormat("MostRecentEWTTouches called with\n symbol=%s\n start_index=%d\n lewt_index=%d, sewt_index=%d",symbol,start_index,lewt_index,sewt_index));
    
    // find most recent touch in highs
    for (int bar = 0; bar < 365; bar++)
    {
        // current bar value
        double bar_val = iHigh(symbol,PERIOD_D1,bar);
        // value of ewt at bar
        double ewt_val = iHigh(symbol,PERIOD_D1,EWT_HIGH[bar]);
                
        if(bar_val == ewt_val)
        {
            // this is a touch
            lewt_index = bar;
            // print out the date
            datetime date_time = iTime(symbol,PERIOD_D1,bar);
            int MN=TimeMonth(date_time); // Month         
            int DD=TimeDay(date_time);   // Day
            int HH=TimeHour(date_time);  // Hour
            PrintMsg(DebugLogHandle,StringFormat("Found a touch on high: bar=%d\n Date=%d-%d_%d",bar,MN,DD,HH));
            break;
        }
    }
    
    // find most recent touch in lows
    for (int bar = 0; bar < 365; bar++)
    {
        // current bar value
        double bar_val = iLow(symbol,PERIOD_D1,bar);
        // value of ewt at bar
        double ewt_val = iLow(symbol,PERIOD_D1,EWT_LOW[bar]);
        
        if(bar_val == ewt_val)
        {
            // this is a touch
            sewt_index = bar;
            // print out the date
            datetime date_time = iTime(symbol,PERIOD_D1,bar);
            int MN=TimeMonth(date_time); // Month         
            int DD=TimeDay(date_time);   // Day
            int HH=TimeHour(date_time);  // Hour
            PrintMsg(DebugLogHandle,StringFormat("Found a touch on low: bar=%d\n Date=%d-%d_%d",bar,MN,DD,HH));
            break;
        }
    }
    
    PrintMsg(DebugLogHandle,StringFormat("MostRecentEWTTouches returned with\n lewt_index=%d, sewt_index=%d",lewt_index,sewt_index));

}
//+--------------------------------------------------------------------------------------------------------------------+
void NextEWTTouchesForward(string symbol, int start_index, int& lewt_index, int& sewt_index)
{
    PrintMsg(DebugLogHandle,StringFormat("NextEWTTouchesForward called with\n symbol=%s\n start_index=%d\n lewt_index=%d, sewt_index=%d",symbol,start_index,lewt_index,sewt_index));

    // find most recent index in either high or lows where value = EWT value
    if (start_index <= 0)
    {
        lewt_index = -1;
        sewt_index = -1;
        return;
    }
    for (int bar = start_index; bar >= 0; bar--)
    {
        double bar_val = iHigh(symbol,PERIOD_D1,bar);
        // value of ewt at bar
        double ewt_val = iHigh(symbol,PERIOD_D1,EWT_HIGH[bar]);
                
        if(bar_val == ewt_val)
        {
            // this is a touch
            lewt_index = bar;
            // print out the date
            datetime date_time = iTime(symbol,PERIOD_D1,bar);
            int MN=TimeMonth(date_time); // Month         
            int DD=TimeDay(date_time);   // Day
            int HH=TimeHour(date_time);  // Hour
            PrintMsg(DebugLogHandle,StringFormat("Found a touch on high: bar=%d\n Date=%d-%d_%d",bar,MN,DD,HH));
            break;
        }
    }
    for (int bar = start_index; bar >= 0; bar--)
    {
        // current bar value
        double bar_val = iLow(symbol,PERIOD_D1,bar);
        // value of ewt at bar
        double ewt_val = iLow(symbol,PERIOD_D1,EWT_LOW[bar]);
        
        if(bar_val == ewt_val)
        {
            // this is a touch
            sewt_index = bar;
            // print out the date
            datetime date_time = iTime(symbol,PERIOD_D1,bar);
            int MN=TimeMonth(date_time); // Month         
            int DD=TimeDay(date_time);   // Day
            int HH=TimeHour(date_time);  // Hour
            PrintMsg(DebugLogHandle,StringFormat("Found a touch on low: bar=%d\n Date=%d-%d_%d",bar,MN,DD,HH));
            break;
        }
    }
    PrintMsg(DebugLogHandle,StringFormat("NextEWTTouchesForward returned with\n lewt_index=%d, sewt_index=%d",lewt_index,sewt_index));

}
//+--------------------------------------------------------------------------------------------------------------------+
int FindIndexOfDirectionChangefromIndex(string symbol, int index, int IsHigh)
{
    datetime date_time = iTime(symbol,PERIOD_D1,index);
    int MN=TimeMonth(date_time); // Month         
    int DD=TimeDay(date_time);   // Day
    int HH=TimeHour(date_time);  // Hour
    //PrintMsg(DebugLogHandle,StringFormat("Found a touch on low: bar=%d\n Date=%d-%d_%d",bar,MN,DD,HH));
            
    PrintMsg(DebugLogHandle,StringFormat("FindIndexOfDirectionChangefromIndex called with %s, point 2=%d, Date=%d-%d_%d, Ishigh=%d",symbol,index,MN,DD,HH,IsHigh));
    bool dir_change = false;
    int index_of_change = -1;
    
    if (IsHigh)
    {
        PrintMsg(DebugLogHandle,"Finding direction change of high touch");

        // High
        // Get value of current touch
        double val = iHigh(symbol,PERIOD_D1,index);
        int current_index = index;
        double prev_val = -1;
        while(!dir_change)
        {
            // get previous ewt value
            current_index++;
            prev_val = val;
            val = EWTValueAtIndex(symbol,current_index,IsHigh);
            PrintMsg(DebugLogHandle,StringFormat("Is High = true, Traversing back through value %f at index %d, (prev=%f)",val,current_index,prev_val));
            if (val > prev_val)
            {
                PrintMsg(DebugLogHandle,"Trend on high is downwards");
                // trend is downward - can this even happen??
                // Does this mean that this point is the change of direction?
            }
            else if(val < prev_val)
            {
                PrintMsg(DebugLogHandle,"Trend on high is upwards");
                // trend is upward
                // find when direction changed, looking back from here.
                // values on same trend will be < this value, find next > value
                
                while(!dir_change)
                {
                    prev_val = val;
                    // get previous ewt value
                    current_index++;
                    val = EWTValueAtIndex(symbol,current_index,IsHigh);
                    date_time = iTime(symbol,PERIOD_D1,current_index);
                    MN=TimeMonth(date_time); // Month         
                    DD=TimeDay(date_time);   // Day
                    HH=TimeHour(date_time);  // Hour
                    PrintMsg(DebugLogHandle,StringFormat("debug current val = %f prev val = %f, current_index %d, Date=%d-%d_%d",val,prev_val, current_index,MN,DD,HH));
                    if (val > prev_val)
                    {
                        date_time = iTime(symbol,PERIOD_D1,current_index);
                        MN=TimeMonth(date_time); // Month         
                        DD=TimeDay(date_time);   // Day
                        HH=TimeHour(date_time);  // Hour
                        PrintMsg(DebugLogHandle,StringFormat("Found 1st direction change at index %d, Date=%d-%d_%d, val=%f,now reversing",current_index,MN,DD,HH,val));
                        // found direction change, now reverse and find first upward breakout
               
                        while(!dir_change)
                        {
                            prev_val = val;
                            // get next ewt value
                            current_index--;
                            val = EWTValueAtIndex(symbol,current_index,IsHigh);
                            if(val > prev_val)
                            {
                                date_time = iTime(symbol,PERIOD_D1,current_index);
                                MN=TimeMonth(date_time); // Month         
                                DD=TimeDay(date_time);   // Day
                                HH=TimeHour(date_time);  // Hour
                                PrintMsg(DebugLogHandle,StringFormat("Found 2nd direction change at index %d, Date=%d-%d_%d",current_index,MN,DD,HH));
              
                                // THIS IS POINT 3*****************
                                index_of_change = current_index;
                                dir_change = true;
                            }
                        }
                    }
                }
            }
            else
            {
                // same value
                prev_val = val;
            }
        }
    }
    else
    {
        PrintMsg(DebugLogHandle,"Finding direction change of low touch");

        // Low
        // Get value of current touch
        double val = iLow(symbol,PERIOD_D1,index);
        int current_index = index;
        double prev_val = -1;
        while(!dir_change)
        {
            // get previous ewt value
            current_index++;
            prev_val = val;
            val = EWTValueAtIndex(symbol,current_index,IsHigh);
            PrintMsg(DebugLogHandle,StringFormat("Is High = false, Traversing back through value %f at index %d, (prev=%f)",val,current_index,prev_val));
            if (val > prev_val)
            {
                PrintMsg(DebugLogHandle,"Trend on low is downwards");
                // trend is upward
                // find when direction changed, looking back from here.
                // values on same trend will be > this value, find next < value
                
                while(!dir_change)
                {
                    prev_val = val;
                    // get previous ewt value
                    current_index++;
                    val = EWTValueAtIndex(symbol,current_index,IsHigh);
                    if (val < prev_val)
                    {
                        date_time = iTime(symbol,PERIOD_D1,current_index);
                        MN=TimeMonth(date_time); // Month         
                        DD=TimeDay(date_time);   // Day
                        HH=TimeHour(date_time);  // Hour
                        PrintMsg(DebugLogHandle,StringFormat("Found 1st direction change at index %d, Date=%d-%d_%d, val=%f,now reversing",current_index,MN,DD,HH,val));
                        // found direction change, now reverse and find first upward breakout
               
                        while(!dir_change)
                        {
                            prev_val = val;
                            // get next ewt value
                            current_index--;
                            val = EWTValueAtIndex(symbol,current_index,IsHigh);
                            if(val < prev_val)
                            {
                                date_time = iTime(symbol,PERIOD_D1,current_index);
                                MN=TimeMonth(date_time); // Month         
                                DD=TimeDay(date_time);   // Day
                                HH=TimeHour(date_time);  // Hour
                                PrintMsg(DebugLogHandle,StringFormat("Found 2nd direction change at index %d, Date=%d-%d_%d",current_index,MN,DD,HH));
              
                                // THIS IS POINT 3*****************
                                index_of_change = current_index;
                                dir_change = true;
                            }
                        }
                    }
                }
                
            }
            else if(val < prev_val)
            {
                PrintMsg(DebugLogHandle,"Trend on low is upwards");
                // trend is downward - can this even happen??
                // Does this mean that this point is the change of direction?
            }
            else
            {
                // same value
                prev_val = val;
            }
        }
    }
    PrintMsg(DebugLogHandle,StringFormat("FindIndexOfDirectionChangefromIndex returned index %f, Date=%d-%d_%d",index_of_change,MN,DD,HH));
    return index_of_change;
}
//+--------------------------------------------------------------------------------------------------------------------+
bool MakePendingOrder(Instrument &inst, int ttype)
{
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder called with\n instrument=%s ttype=%d",inst.AsString(),ttype));

    bool trade_placed = false;
    double ATR15 = iATR(inst.symbol,PERIOD_D1,15,0);
    double RV = 2*ATR15;
    double RV_pips = RV / inst.pip_location;
    double volume = 0;
    double ex_rate = 0;
    if(inst.base_currency_chart == "GBP")
    {
        ex_rate = 1;
    }
    else
    {
        ex_rate = iClose(inst.base_currency_chart,PERIOD_D1,0);
    }
    
    double AccBalance = AccountBalance() / 100;
    double RV_money = (AccBalance / 100) * ex_rate;
    double PIP_value = RV_money / RV_pips;
    double Trade_size = PIP_value / inst.pip_location;
    double Trade_size_MT4 = Trade_size / inst.lot_size;
    double Trade_size_MT4_rounded = floor(Trade_size_MT4 * 100) / 100; // round down to 2 decimal places
    
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: ATR15[%f]",ATR15));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: inst.base_currency_chart[%s]",inst.base_currency_chart));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: ex_rate[%f]",ex_rate));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: AccBalance[%f]",AccBalance));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: RV[%f]",RV));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: RV_pips[%f]",RV_pips));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: RV_money[%f]",RV_money));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: PIP_value[%f]",PIP_value));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: Trade_size[%f]",Trade_size));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: Trade_size_MT4[%f]",Trade_size_MT4));
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: Trade_size_MT4_rounded[%f]",Trade_size_MT4_rounded));
    
    if(Trade_size_MT4_rounded == 0) 
    {
        PrintMsg(DebugLogHandle, "MakePendingOrder: Returned. NO TRADE SIZE AVAILABLE"); 
        return false;
    }
    //*************************
    double price = 0;
    int slippage = 0;
    //*************************
    // Calculate StopLoss
    double stoploss = 0;
    //*************************
    double takeprofit = 0;
    
    if(ttype == LSMS)
    {
    //int OrderSend (string symbol, int cmd, double volume, double price, int slippage, double stoploss,
    //              double takeprofit, string comment=NULL, int magic=0, datetime expiration=0, color arrow_color=clrGreen)
        int lsms_index = -1;
        double lsms_value = -1;
        lsms_index = iHighest(inst.symbol,PERIOD_D1,MODE_HIGH,CONST_SMS_PERIOD,0);
        if(lsms_index > -1)
        {
            lsms_value = iHigh(inst.symbol,PERIOD_D1,lsms_index);
            if(lsms_value > -1)
            {
                price = lsms_value;
                stoploss = (price - RV);
                takeprofit = price + (100 * RV);
                string comment = "jk_lsms";

                int ticket = 1111; //OrderSend(inst.symbol,OP_BUYSTOP,Trade_size_MT4_rounded,price,0,stoploss,takeprofit,comment,0,0,clrGreen);
                PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend:Symbol[%s],cmd[BUYSTOP],volume[%f],price[%f],slippage[0],stoploss[%f],takeprofit[%f],comment[%s],magic[0],expiration[0],color[clrGreen]",
                                                inst.symbol,Trade_size_MT4_rounded,price,stoploss,takeprofit,comment));
                                                
                if(ticket < 0)
                {
                    int error = GetLastError();
                    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend:Symbol[%s], ERROR placing trade: [%d] description: [%s]",
                                                inst.symbol,error,ErrorDescription(error)));
                }
                else
                {
                    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend placed successfully. Ticket no:[%d]",ticket));
                    trade_placed = true;
                    inst.lsms_trade = ticket;
                    Trade trade;
                    trade.Clear();
                    trade.ticket_number = ticket;
                    trade.symbol = inst.symbol;
                    trade.price = price;
                    trade.volume = Trade_size_MT4_rounded;
                    trade.stoploss = stoploss;
                    trade.take_profit = takeprofit;
                    trade.comment = comment;
                    trade.trade_type = LSMS;
                    LogTrade(trade);
                }
            }
        }
    }
            
    if(ttype == LEWT)
    {
        int lewt_index = -1;
        double lewt_value = -1;
        lewt_index = iHighest(inst.symbol,PERIOD_D1,MODE_HIGH,CONST_EWT_PERIOD,0);
        if(lewt_index > -1)
        {
            lewt_value = iHigh(inst.symbol,PERIOD_D1,lewt_index);
            if(lewt_value > -1)
            {
                price = lewt_value;
                stoploss = (price - RV);
                takeprofit = price + (100 * RV);
                string comment = "jk_lewt";

                int ticket = 2222; //OrderSend(inst.symbol,OP_BUYSTOP,Trade_size_MT4_rounded,price,0,stoploss,takeprofit,comment,0,0,clrGreen);
                PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend:Symbol[%s],cmd[BUYSTOP],volume[%f],price[%f],slippage[0],stoploss[%f],takeprofit[%f],comment[%s],magic[0],expiration[0],color[clrGreen]",
                                                inst.symbol,Trade_size_MT4_rounded,price,stoploss,takeprofit,comment));            
                
                                                
                if(ticket < 0)
                {
                    int error = GetLastError();
                    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend:Symbol[%s], ERROR placing trade: [%d] description: [%s]",
                                                inst.symbol,error,ErrorDescription(error)));
                }
                else
                {
                    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend placed successfully. [%s] Ticket no:[%d]",comment,ticket));
                    trade_placed = true;
                    inst.lewt_trade = ticket;
                    Trade trade;
                    trade.Clear();
                    trade.ticket_number = ticket;
                    trade.symbol = inst.symbol;
                    trade.price = price;
                    trade.volume = Trade_size_MT4_rounded;
                    trade.stoploss = stoploss;
                    trade.take_profit = takeprofit;
                    trade.comment = comment;
                    trade.trade_type = LEWT;
                    LogTrade(trade);
                }
            }
                                                
        }
    }
        
    if(ttype == SEWT)
    {
        int sewt_index = -1;
        double sewt_value = -1;
        sewt_index = iLowest(inst.symbol,PERIOD_D1,MODE_LOW,CONST_EWT_PERIOD,0);
        if(sewt_index > -1)
        {
            sewt_value = iLow(inst.symbol,PERIOD_D1,sewt_index);
            if(sewt_value > -1)
            {
                price = sewt_value;
                stoploss = (price + RV);
                takeprofit = price - (100 * RV);
                if(takeprofit < 0){takeprofit = 0;}
                string comment = "jk_sewt";
    
                int ticket = 3333; //OrderSend(inst.symbol,OP_SELLSTOP,Trade_size_MT4_rounded,price,0,stoploss,takeprofit,comment,0,0,clrGreen);
                PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend:Symbol[%s],cmd[BUYSTOP],volume[%f],price[%f],slippage[0],stoploss[%f],takeprofit[%f],comment[%s],magic[0],expiration[0],color[clrGreen]",
                                                inst.symbol,Trade_size_MT4_rounded,price,stoploss,takeprofit,comment));            
                
                                                
                if(ticket < 0)
                {
                    int error = GetLastError();
                    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend:Symbol[%s], ERROR placing trade: [%d] description: [%s]",
                                                inst.symbol,error,ErrorDescription(error)));
                }
                else
                {
                    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend placed successfully. [%s] Ticket no:[%d]",comment,ticket));
                    trade_placed = true;
                    inst.sewt_trade = ticket;
                    Trade trade;
                    trade.Clear();
                    trade.ticket_number = ticket;
                    trade.symbol = inst.symbol;
                    trade.price = price;
                    trade.volume = Trade_size_MT4_rounded;
                    trade.stoploss = stoploss;
                    trade.take_profit = takeprofit;
                    trade.comment = comment;
                    trade.trade_type = SEWT;
                    LogTrade(trade);
                }
            }
        }
    }
    if(ttype == SSMS)
    {
        int ssms_index = -1;
        double ssms_value = -1;
        ssms_index = iLowest(inst.symbol,PERIOD_D1,MODE_LOW,CONST_SMS_PERIOD,0);
        if(ssms_index > -1)
        {
            ssms_value = iLow(inst.symbol,PERIOD_D1,ssms_index);
            if(ssms_value > -1)
            {
                price = ssms_value;
                stoploss = (price + RV);
                takeprofit = price - (100 * RV);
                if(takeprofit < 0){takeprofit = 0;}
                string comment = "jk_ssms";

                int ticket = 4444; //OrderSend(inst.symbol,OP_SELLSTOP,Trade_size_MT4_rounded,price,0,stoploss,takeprofit,comment,0,0,clrGreen);
                PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend:Symbol[%s],cmd[BUYSTOP],volume[%f],price[%f],slippage[0],stoploss[%f],takeprofit[%f],comment[%s],magic[0],expiration[0],color[clrGreen]",
                                                inst.symbol,Trade_size_MT4_rounded,price,stoploss,takeprofit,comment));            
                
                                                
                if(ticket < 0)
                {
                    int error = GetLastError();
                    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend:Symbol[%s], ERROR placing trade: [%d] description: [%s]",
                                                inst.symbol,error,ErrorDescription(error)));
                }
                else
                {
                    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: OrderSend placed successfully. [%s] Ticket no:[%d]",comment,ticket));
                    trade_placed = true;
                    inst.ssms_trade = ticket;
                    Trade trade;
                    trade.Clear();
                    trade.ticket_number = ticket;
                    trade.symbol = inst.symbol;
                    trade.price = price;
                    trade.volume = Trade_size_MT4_rounded;
                    trade.stoploss = stoploss;
                    trade.take_profit = takeprofit;
                    trade.comment = comment;
                    trade.trade_type = SSMS;
                    LogTrade(trade);
                }
            }
        }
    }   
    PrintMsg(DebugLogHandle,StringFormat("MakePendingOrder: returned trade_placed = %s",(trade_placed ? "true" : "false")));

    return trade_placed;
}
//+--------------------------------------------------------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- Open files
    DebugLogHandle=FileOpen(DebugLogFilename,FILE_CSV|FILE_WRITE|FILE_ANSI);
    if(DebugLogHandle == -1){ return; }
    
    
//--- Initialise Instruments
    //BuildInstrumentList();
    
    ReadInstrsLog();
    
    for(int index = 0; index < 17; index++)
    {
        PrintMsg(DebugLogHandle,StringFormat("just read in:\n%s",Instrs[index].AsString()));
    }
//--- Calc LTCT    
    
    for(int index = 3; index < 4; index++)
    {
        bool profit = false;
        PrintMsg(DebugLogHandle,StringFormat("********** %s ***************************************************",Instrs[index].symbol));
        if(CalculateLTCT(Instrs[index].symbol,profit))
        {
            PrintMsg(DebugLogHandle,"CalculateLCTC return an error");
            return;
        }
        double lewt_value = -1;
        double sewt_value = -1;
        
//--- Make new trades
        if(!profit)
        {
            PrintMsg(DebugLogHandle,"OnStart: LTCT = loss, setting up EWT trades");

//--- LEWT
            PrintMsg(DebugLogHandle,"OnStart: setting up LEWT trade");
            // make trade for LEWT
            int lewt_index = -1;
            
            lewt_index = iHighest(Instrs[index].symbol,PERIOD_D1,MODE_HIGH,CONST_EWT_PERIOD,0);
            if(lewt_index > -1)
            {
                lewt_value = iHigh(Instrs[index].symbol,PERIOD_D1,lewt_index);
                if(lewt_value > -1)
                {
                    MakePendingOrder(Instrs[index], LEWT);
                }
                else
                {
                    PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: error in LEWT value.",Instrs[index].symbol));
                }
            }
            else
            {
                PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: error in LEWT index.",Instrs[index].symbol));
            }
//--- SEWT        
            // make trade for SEWT
            int sewt_index = -1;
            
            PrintMsg(DebugLogHandle,"OnStart: setting up SEWT trade");
            sewt_index = iLowest(Instrs[index].symbol,PERIOD_D1,MODE_LOW,CONST_EWT_PERIOD,0);
            if(sewt_index > -1)
            {
                sewt_value = iLow(Instrs[index].symbol,PERIOD_D1,sewt_index);
                if(sewt_value > -1)
                {
                    MakePendingOrder(Instrs[index], SEWT);
                }
                else
                {
                    PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: error in SEWT value.",Instrs[index].symbol));
                }
            }
            else
            {
                PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: error in SEWT index.",Instrs[index].symbol));
            }
        }
//--- LSMS
        PrintMsg(DebugLogHandle,"OnStart: setting up LSMS trade");
        int lsms_index = -1;
        lsms_index = iHighest(Instrs[index].symbol,PERIOD_D1,MODE_HIGH,CONST_SMS_PERIOD,0);
        if(lsms_index > -1)
        {
            double lsms_value = iHigh(Instrs[index].symbol,PERIOD_D1,lsms_index);
            if(lsms_value > -1)
            {
                if(lsms_value != lewt_value)
                {
                    MakePendingOrder(Instrs[index],LSMS);
                }
                else
                {
                    PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: LSMS == LEWT, LSMS not taken.",Instrs[index].symbol));
                }
            }
            else
            {
                PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: error in SSMS value.",Instrs[index].symbol));
            }
        }
        else
        {
            PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: error in SSMS index.",Instrs[index].symbol));
        }
//--- SSMS
        PrintMsg(DebugLogHandle,"OnStart: setting up SSMS trade");
        int ssms_index = -1;
        ssms_index = iLowest(Instrs[index].symbol,PERIOD_D1,MODE_LOW,CONST_SMS_PERIOD,0);
        if(ssms_index > -1)
        {
            double ssms_value = iLow(Instrs[index].symbol,PERIOD_D1,ssms_index);
            if(ssms_value > -1)
            {
                if(ssms_value != sewt_value)
                {
                    MakePendingOrder(Instrs[index],SSMS);
                }
                else
                {
                    PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: SSMS == SEWT, SSMS not taken.",Instrs[index].symbol));
                }
            }
            else
            {
                PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: error in SSMS value.",Instrs[index].symbol));
            }
        }
        else
        {
            PrintMsg(DebugLogHandle,StringFormat("OnStart: Symbol %s: error in SSMS index.",Instrs[index].symbol));
        }

  
        if(false/*val > 6ATR*/)
        {
            // cancel trade
        } 
             
    }
    WriteInstrsLog(); 
    FileClose(TradeLogHandle);
    TradeLogHandle = -1;  
  }
//+------------------------------------------------------------------+
