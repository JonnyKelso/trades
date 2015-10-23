//+------------------------------------------------------------------+
//|                                                    jonnyEA_1.mq4 |
//|                                     Jonny Kelso, Copyright 2015. |
//|                                             https://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Jonny Kelso, Copyright 2015."
#property link      "https://www.mql4.com"
#property version   "1.00"
#property strict

#include <stderror.mqh>
#include <stdlib.mqh>
#include "Instrument.mqh"
#include "Trade.mqh"


/* constants */
const int CONST_MAX_PERIOD = 60;
const int CONST_SMS_PERIOD = 52;
extern const int CONST_EWT_PERIOD = 10;
const int CONST_NUM_SYMBOLS = 17;
Instrument Instrs[17];
const int CONST_MAX_ALLOW_TRADES = 2;
const int CONST_PERIOD = PERIOD_M1;
const int CONST_EWT_HISTORY_PERIOD = 10000; //bars
int EWT_HIGH[10000];
int EWT_LOW[10000];
int MAX_NUM_TRADES = 150;
Trade Trades[150];
extern const int CONST_RV_MULTIPLIER = 2;
extern const int CONST_STOP_ADJUST_THRESHOLD = 1;

/* filenames and handles */
string InstrsLogFilename= "UTP_InstrsLog.csv";
string DebugLogFilename = "UTP_DebugLog.csv";
string TradeLogFilename = "UTP_TradeLog.csv";
string TradesListFilename = "UTP_TradesList.csv";
int InstrsLogHandle= -1;
int DebugLogHandle = -1;
int TradeLogHandle = -1;
int TradesListHandle = -1;

/* points in the definition of LTCT */
string point1_date = "";
string point2_date = "";
string point3_date = "";
string point4_date = "";



enum DebugLevel
{
    DB_OFF   = 0x0,
    DB_LOW    = 0x1,
    DB_MAX    = 0x2
};
const int CONST_DEBUG_LEVEL = DB_MAX;

/* initialisation of instruments */
/* not used in normal running, only used first time instruments are initialised */
/*                   Symbol         Base        Minimum  Lot         Pip         trade */
/*                                  Currency    Trade    Size        Location    tickets */
/*                                  Chart       Size */
Instrument instr01("EURUSD",        "GBPUSD",   0.01,    100000,     0.0001,     0,0,0,0);       //USD
Instrument instr02("GBPUSD",        "GBPUSD",   0.01,    100000,     0.0001,     0,0,0,0);       //USD
Instrument instr03("EURCHF",        "GBPCHF",   0.01,    100000,     0.0001,     0,0,0,0);       //CHF
Instrument instr04("USDJPY",        "GBPJPY",   0.01,    100000,     0.01,       0,0,0,0);       //JPY
Instrument instr05(".UK100",        "GBP",      0.01,    1,          1,          0,0,0,0);       //GBP
Instrument instr06(".US500",        "GBPUSD",   0.01,    1,          1,          0,0,0,0);       //USD
Instrument instr07("XAUUSD",        "GBPUSD",   0.01,    100,        0.01,       0,0,0,0);       //USD
Instrument instr08("USCotton",      "GBPUSD",   0.01,    10000,      0.01,       0,0,0,0);       //USD
Instrument instr09("USSugar",       "GBPUSD",   0.01,    10000,      0.01,       0,0,0,0);       //USD
Instrument instr10("WTICrude",      "GBPUSD",   0.01,    100,        0.01,       0,0,0,0);       //USD
Instrument instr11("NaturalGas",    "GBPUSD",   0.01,    1000,       0.001,      0,0,0,0);       //USD
Instrument instr12("FACE",          "GBPUSD",   1,       1,          0.01,       0,0,0,0);       //USD
Instrument instr13("GOOG",          "GBPUSD",   1,       1,          0.01,       0,0,0,0);       //USD
Instrument instr14("MSFT",          "GBPUSD",   1,       1,          0.01,       0,0,0,0);       //USD
Instrument instr15("TWTR",          "GBPUSD",   1,       1,          0.01,       0,0,0,0);       //USD
Instrument instr16("USTNote",       "GBPUSD",   1,       100,        0.01,       0,0,0,0);       //USD
Instrument instr17("YHOO",          "GBPUSD",   1,       1,          0.01,       0,0,0,0);       //USD

int timer_count = 0;
bool ran_today = false;
bool ran_this_min = false;
int run_MN = -1;
datetime last_run_datetime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   // set timer to go off every hour
   //EventSetTimer(3600);

   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   //EventKillTimer();
   FileClose(DebugLogHandle);
   DebugLogHandle=-1;
    
  }
int OpenDebugFile()
{
    string time_now_str = GetTimeNow();
    if(DebugLogHandle < 0)
    {
        DebugLogFilename=StringFormat("UTP_DebugLog_%s.csv",time_now_str);
        DebugLogHandle=FileOpen(DebugLogFilename,FILE_CSV|FILE_WRITE|FILE_ANSI);
    }
    if(DebugLogHandle==-1)
    { 
        return -1; 
    }
    return 0;
}

void OnTick()
{
    // get time now
    datetime now_datetime=TimeLocal();
    int YY=TimeYear(now_datetime);
    int MM=TimeMonth(now_datetime);
    int DD=TimeDay(now_datetime);
    int HH=TimeHour(now_datetime);
    int MN=TimeMinute(now_datetime);
    int  S=TimeSeconds(now_datetime);

    // is it time to run yet?
    // only run once a minute
    if(now_datetime > (last_run_datetime + 60))
    {
        string time_string=StringFormat("%04d-%02d-%02d_%02d-%02d-%02d",YY,MM,DD,HH,MN,S);
        PrintFormat("time now = %s",time_string);
        last_run_datetime = now_datetime;
        Start();
    }
}
//+------------------------------------------------------------------+
//| Expert timer function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
    //---
    timer_count++;
    return;
 /*
    // get time now
    datetime date_time=TimeLocal();
    int YY=TimeYear(date_time);
    int MM=TimeMonth(date_time);
    int DD=TimeDay(date_time);
    int HH=TimeHour(date_time);
    int MN=TimeMinute(date_time);
    int  S=TimeSeconds(date_time);
    string time_string=StringFormat("%04d-%02d-%02d_%02d-%02d-%02d",YY,MM,DD,HH,MN,S);
    // is it time to run yet?
    // only run once a day
    if(HH == 13)
    {
        //string time_string=StringFormat("%04d-%02d-%02d_%02d-%02d-%02d",YY,MM,DD,HH,MN,S);
        PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Starting run, time = %s",time_string));
        Start();
        ran_today = true;
    }
    else
    {
        if(HH == 0) // midnight
        {
            ran_today = false;
        }
        PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Waiting for run time, time = %s, ran today? = %s",time_string,(ran_today ? "yes" : "no")));
        Print("hello");
    }
 */
}

/*------------------------------------------------------------------
 * Script program start function                                    
 *------------------------------------------------------------------*/
void Start()
{
    int res = OpenDebugFile();

    //BuildInstrumentList();
    ReadInstrsLog();
    //ReadTradesList();
    //ReadTradeLog();
    //PrintTradesList();
    ReadTradesFromAccount();
    
    
    //for(int trade_index=0; trade_index<MAX_NUM_TRADES; trade_index++)
    //{
       // PrintMsg(DebugLogHandle,DB_LOW,StringFormat("********** %s ***************************************************\n%s\n",Instrs[instr_index].symbol,Instrs[instr_index].AsString()));

        //double sms_long_price = 0.0;
    double ewt_long_price = 0.0;
    double ewt_short_price = 0.0;
       // double sms_short_price = 0.0;
    int lewt_ticket_num = -1;
    int sewt_ticket_num = -1;
    for(int trade_index = 0; trade_index < MAX_NUM_TRADES; trade_index++)
    {
        if(Trades[trade_index].trade_type == TT_LEWT)
        {
            lewt_ticket_num = Trades[trade_index].ticket_number;
        }
        else if(Trades[trade_index].trade_type == TT_SEWT)
        {
            sewt_ticket_num = Trades[trade_index].ticket_number;
        }
    }
        
    int instr_index = 0;
//--- LEWT
        //int ticket_num = Instrs[instr_index].lewt_trade;
        // do we already have a trade here?
        if(lewt_ticket_num > 0)
        {
            PrintMsg(DebugLogHandle,DB_LOW,"OnStart: Checking LEWT trade");
            int trade_index = GetTradeIndexFromTicketNumber(lewt_ticket_num);
            if(trade_index >= 0)
            {
                CheckTrade(trade_index, instr_index);
                ewt_long_price = Trades[trade_index].open_price;
            }
        }
        else
        {
            // we're good to go
            PrintMsg(DebugLogHandle,DB_LOW,"OnStart: Making LONG LEWT trade");
            // this is an empty trade slot
            // make new trade if possible
            if(GetNumberActiveTrades() < CONST_MAX_ALLOW_TRADES)
            {
                ewt_long_price = MakeTrade(Instrs[instr_index],TT_LEWT);
            }
            else
            {
                PrintMsg(DebugLogHandle,DB_LOW,"OnStart: LEWT Reached CONST_MAX_ALLOW_TRADES limit");
            }
        }
//--- SEWT        
        //ticket_num = Instrs[instr_index].sewt_trade;
        // do we already have a trade here?
        if(sewt_ticket_num > 0)
        {
            PrintMsg(DebugLogHandle,DB_LOW,"OnStart: Checking SEWT trade");
            int trade_index = GetTradeIndexFromTicketNumber(sewt_ticket_num);
            if(trade_index >= 0)
            {
                CheckTrade(trade_index, instr_index);
                ewt_short_price = Trades[trade_index].open_price;
            }
            
        }
        else
        {
            PrintMsg(DebugLogHandle,DB_LOW,"OnStart: Making SHORT SEWT trade");
            // this is an empty trade slot
            // make new trade if possible
            if(GetNumberActiveTrades() < CONST_MAX_ALLOW_TRADES)
            {
                ewt_short_price = MakeTrade(Instrs[instr_index],TT_SEWT);
            }
            else
            {
                PrintMsg(DebugLogHandle,DB_LOW,"OnStart: SEWT Reached CONST_MAX_ALLOW_TRADES limit");
            }
        }
   // }
    //WriteInstrsList();
    //WriteTradesList();
    //FileClose(TradeLogHandle);
    //TradeLogHandle=-1;
    //FileClose(DebugLogHandle);
    //DebugLogHandle=-1;

  }
//+------------------------------------------------------------------+

string GetTimeNow()
{
   datetime date_time=TimeLocal();
   int YY=TimeYear(date_time);
   int MM=TimeMonth(date_time);
   int DD=TimeDay(date_time);
   int HH=TimeHour(date_time);
   int MN=TimeMinute(date_time);
   int  S=TimeSeconds(date_time);
   string time_string=StringFormat("%04d-%02d-%02d_%02d-%02d-%02d",YY,MM,DD,HH,MN,S);
   return time_string;
}

/*--------------------------------------------------------------------------------------------------------------------*/
/* A wrapper for FileWriteString that checks the file handle is valid and appends a \n to the string */
void PrintMsg(int hndl,DebugLevel level,string msg)
{
    if(level <= CONST_DEBUG_LEVEL)
    {
        Print(msg);
        if(hndl>-1)
        {
            msg=msg+"\n";
            FileWriteString(hndl,msg,256);
        }
    }
}

void BuildInstrumentList()
{
   PrintMsg(DebugLogHandle,DB_MAX,"BuildInstrumentList called");
   /*
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
   */
   Instrs[0].Copy(instr01);
   Instrs[1].Copy(instr02);
   Instrs[2].Copy(instr03);
   Instrs[3].Copy(instr04);
   Instrs[4].Copy(instr05);
   Instrs[5].Copy(instr06);
   Instrs[6].Copy(instr07);
   Instrs[7].Copy(instr08);
   Instrs[8].Copy(instr09);
   Instrs[9].Copy(instr10);
   Instrs[10].Copy(instr11);
   Instrs[11].Copy(instr12);
   Instrs[12].Copy(instr13);
   Instrs[13].Copy(instr14);
   Instrs[14].Copy(instr15);
   Instrs[15].Copy(instr16);
   Instrs[16].Copy(instr17);
   PrintMsg(DebugLogHandle,DB_MAX,"BuildInstrumentList returned");

}


/*--------------------------------------------------------------------------------------------------------------------*/
/* To copy one instrument into an empty one */
/* Is only used as part of BuildInstrumentList */
void InstrumentCopy(Instrument &a,Instrument &b)
  {
   a.symbol=b.symbol;
   a.base_currency_chart=b.base_currency_chart;
   a.min_trade_size=b.min_trade_size;
   a.lot_size=b.lot_size;
   a.pip_location=b.pip_location;
  }

/*--------------------------------------------------------------------------------------------------------------------*/
/* Populate the Instrs array of instruments from file */
int ReadInstrsLog()
{
    int result = 0;
    PrintMsg(DebugLogHandle,DB_MAX,"ReadInstrsLog called");
    InstrsLogHandle= -1;
    InstrsLogHandle=FileOpen(InstrsLogFilename,FILE_CSV|FILE_READ);
    if(InstrsLogHandle>-1)
    {
        while(!FileIsEnding(InstrsLogHandle))
        {
            for(int index=0; index<CONST_NUM_SYMBOLS; index++)
            {
                string symbol_str="";
                string line=FileReadString(InstrsLogHandle,1);
                string separator=",";
                ushort sep=StringGetCharacter(separator,0);
                string strings[];
                int num_substrs=StringSplit(line,sep,strings);
                if(num_substrs>0)
                {
                    Instrs[index].symbol=strings[0];
                    Instrs[index].base_currency_chart=strings[1];
                    Instrs[index].min_trade_size=StringToDouble(strings[2]);
                    Instrs[index].lot_size=StringToDouble(strings[3]);
                    Instrs[index].pip_location=StringToDouble(strings[4]);
                    Instrs[index].lsms_trade = (int)StringToInteger(strings[5]);
                    Instrs[index].lewt_trade = (int)StringToInteger(strings[6]);
                    Instrs[index].sewt_trade = (int)StringToInteger(strings[7]);
                    Instrs[index].ssms_trade = (int)StringToInteger(strings[8]);
                    
                    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Instrs[%d]=%s",index,Instrs[index].AsString()));
                }
            }
            break;
        }
        FileClose(InstrsLogHandle);
        InstrsLogHandle=-1;
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_LOW,"ReadInstrsLog - Invalid file handle passed");
        result = -1;
    }
    PrintMsg(DebugLogHandle,DB_MAX,"ReadInstrsLog returned");
    return result;
}

/*--------------------------------------------------------------------------------------------------------------------*/
/* Write Instrs array to file */
int WriteInstrsList()
{
    PrintMsg(DebugLogHandle,DB_MAX,"WriteInstrsList called");
    if(InstrsLogHandle>-1)
    {
        FileClose(InstrsLogHandle);
        InstrsLogHandle=-1;
    }
    InstrsLogHandle=FileOpen(InstrsLogFilename,FILE_CSV|FILE_WRITE|FILE_ANSI);
    if(InstrsLogHandle==-1){ return 1; }

    for(int index=0; index<CONST_NUM_SYMBOLS; index++)
    {
        FileWriteString(InstrsLogHandle,Instrs[index].AsString());
    }
    FileClose(InstrsLogHandle);
    InstrsLogHandle=-1;

    PrintMsg(DebugLogHandle,DB_MAX,"WriteInstrsList returned");
    return 0;
}

/*--------------------------------------------------------------------------------------------------------------------*/
/* Read the trades list */
int ReadTradesList()
{
    int result = 0;
    PrintMsg(DebugLogHandle,DB_MAX,"ReadTradesList called");
    TradesListHandle= -1;
    TradesListHandle=FileOpen(TradesListFilename,FILE_CSV|FILE_READ);
    if(TradesListHandle>-1)
    {
        int index = 0;
        while(!FileIsEnding(TradesListHandle))
        {
            //string symbol_str="";
            string line=FileReadString(TradesListHandle,1);
            string separator=",";
            ushort sep=StringGetCharacter(separator,0);
            string strings[];
            int num_substrs=StringSplit(line,sep,strings);
            if(num_substrs>0)
            {
                Trades[index].ticket_number=(int)StringToInteger(strings[0]);
                Trades[index].symbol=strings[1];
                Trades[index].open_price=StringToDouble(strings[2]);
                Trades[index].open_time=StringToTime(strings[3]);
                Trades[index].close_price=StringToDouble(strings[4]);
                Trades[index].close_time=StringToTime(strings[5]);
                Trades[index].volume=StringToDouble(strings[6]);
                Trades[index].stoploss=StringToDouble(strings[7]);
                Trades[index].take_profit = StringToDouble(strings[8]);
                Trades[index].commission = StringToDouble(strings[9]);
                Trades[index].swap = StringToDouble(strings[10]);
                Trades[index].profit = StringToDouble(strings[11]);
                Trades[index].magic_number = StringToDouble(strings[12]);
                Trades[index].expiration_date = StringToTime(strings[13]);
                Trades[index].comment = strings[14];
                PrintMsg(DebugLogHandle,DB_MAX,StringFormat("trade type ==== %s",strings[15]));
                Trades[index].SetTradeType(StringFormat("%s",strings[15]));
                PrintMsg(DebugLogHandle,DB_MAX,StringFormat("trade op ==== %s",strings[16]));
                Trades[index].SetTradeOperation(StringFormat("%s",strings[16]));
                PrintMsg(DebugLogHandle,DB_MAX,StringFormat("filled ==== %s",strings[17]));
                Trades[index].SetIsFilled(StringFormat("%s",strings[17]));
                PrintMsg(DebugLogHandle,DB_MAX,StringFormat("trade state ==== %s",strings[18]));
                Trades[index].SetTradeState(StringFormat("%s",strings[18]));
                
                PrintMsg(DebugLogHandle,DB_MAX,StringFormat("ReadTradesList: Trades[%d]=%s",index,Trades[index].AsString()));            
            }
            index++;
        }
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("ReadTradesList - Could not find TradesListFilename = %s",TradesListFilename));
        result = -1;
    }
    FileClose(TradesListHandle);
    TradesListHandle=-1;
    PrintMsg(DebugLogHandle,DB_MAX,"ReadTradesList returned");

    return result;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* Write (append) a Trade to the trade log */
int WriteTradeLog(Trade &trade)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("WriteTradeLog called with trade = %s",trade.AsString()));

    if(TradeLogHandle==-1)
    {
        TradeLogHandle=FileOpen(TradeLogFilename,FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI);
    }
    //ulong offset_bytes = FileSize(TradeLogHandle);

    FileSeek(TradeLogHandle,0,SEEK_END);
    FileWriteString(TradeLogHandle,StringFormat("%s",trade.AsString()));
    //FileClose(TradeLogHandle);
    //TradeLogHandle = -1;

    PrintMsg(DebugLogHandle,DB_MAX,"WriteTradeLog returned");

    return 0;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* Write Trades array to file */
int WriteTradesList()
{
    PrintMsg(DebugLogHandle,DB_MAX,"WriteTradesList called");
    if(TradesListHandle>-1)
    {
        FileClose(TradesListHandle);
        TradesListHandle=-1;
    }
    TradesListHandle=FileOpen(TradesListFilename,FILE_CSV|FILE_WRITE|FILE_ANSI);
    if(TradesListHandle==-1){ return 1; }

    for(int index=0; index<MAX_NUM_TRADES; index++)
    {
        if(Trades[index].trade_state != TS_INVALID && 
           Trades[index].trade_state != TS_CLOSED && 
           Trades[index].trade_state != TS_DELETED)
        {
            FileWriteString(TradesListHandle,Trades[index].AsString());
        }
        
    }
    FileClose(TradesListHandle);
    TradesListHandle=-1;

    PrintMsg(DebugLogHandle,DB_MAX,"WriteTradesList returned");
    return 0;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* Calculate the LTCT, determining the four LTCT points and ultimately whether the LTCT is profit or not */
int CalculateLTCT(string symbol,bool &profit)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("CalculateLTCT called with %s",symbol));

    int error_status=0;
    profit=false;
    string symb=symbol;

    CalculateEWTValues(symb);
    // get most recent ewt touch from today
    int lewt_bar = -1;
    int sewt_bar = -1;
    MostRecentEWTTouches(symb,0,lewt_bar,sewt_bar);
    bool MostRecentIsHigh=false;
    datetime date_time;
    int MN = -1; // Month         
    int DD = -1; // Day
    int HH = -1; // Hour
    int MM = -1; // Min
    int SS = -1; // Sec

    if(lewt_bar>-1 && sewt_bar>-1)
    {

        int point_1_bar = -1;
        int point_2_bar = -1;
        if(lewt_bar>sewt_bar)
        {
            // most recent bar is 0, so sewt_bar touch is more recent than lewt_bar touch
            // *********** POINT 1 = sewt_bar

            point_1_bar=sewt_bar;
            MostRecentIsHigh=false;
            date_time=iTime(symb,CONST_PERIOD,point_1_bar);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            MM=TimeMinute(date_time);// Min
            SS=TimeSeconds(date_time);// Sec
            point1_date=StringFormat("%2dM-%2dD_%2dH-%2dM-%2dS",MN,DD,HH,MM,SS);
            // *********** POINT 2 = lewt_bar
            point_2_bar=lewt_bar;
            date_time=iTime(symb,CONST_PERIOD,point_2_bar);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            MM=TimeMinute(date_time);// Min
            SS=TimeSeconds(date_time);// Sec
            MM=TimeMinute(date_time);// Min
            SS=TimeSeconds(date_time);// Sec
            point2_date=StringFormat("%2dM-%2dD_%2dH-%2dM-%2dS",MN,DD,HH,MM,SS);
        }
        else
        {
            // lewt_bar touch is more recent than sewt_bar touch
            // *********** POINT 1 = lewt_bar
            point_1_bar=lewt_bar;
            MostRecentIsHigh=true;
            date_time=iTime(symb,CONST_PERIOD,point_1_bar);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            MM=TimeMinute(date_time);// Min
            SS=TimeSeconds(date_time);// Sec
            point1_date=StringFormat("%2dM-%2dD_%2dH-%2dM-%2dS",MN,DD,HH,MM,SS);
            // *********** POINT 2 = sewt_bar
            point_2_bar=sewt_bar;
            date_time=iTime(symb,CONST_PERIOD,point_2_bar);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            MM=TimeMinute(date_time);// Min
            SS=TimeSeconds(date_time);// Sec
            point2_date=StringFormat("%2dM-%2dD_%2dH-%2dM-%2dS",MN,DD,HH,MM,SS);
        }
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_LOW,"Error - Couldn't find both recent EWT touches");
        error_status=1;
        return error_status;
    }

    int most_recent_opposite_touch=-1;
    int opposite_touch_is_high=-1;
    int opp_lewt_bar = -1;
    int opp_sewt_bar = -1;
    if(MostRecentIsHigh)
    {
        // most recent touch is on lewt.
        most_recent_opposite_touch=sewt_bar;
        opposite_touch_is_high=0; //low
    }
    else
    {
        // most recent touch is on sewt.
        // get next most recent opposite touch
        most_recent_opposite_touch=lewt_bar;
        opposite_touch_is_high=1; //high
    }

    int direction_change_index=FindIndexOfDirectionChangefromIndex(symb,most_recent_opposite_touch,opposite_touch_is_high);
    date_time=iTime(symb,CONST_PERIOD,direction_change_index);
    MN=TimeMonth(date_time); // Month         
    DD=TimeDay(date_time);   // Day
    HH=TimeHour(date_time);  // Hour
    MM=TimeMinute(date_time);// Min
    SS=TimeSeconds(date_time);// Sec
    point3_date=StringFormat("%2dM-%2dD_%2dH-%2dM-%2dS",MN,DD,HH,MM,SS);

    // **************** (3) mark plot at high/low of index most_recent_opposite_touch depedning on opposite_touch_highlow
    if(direction_change_index>-1)
    {
        // Now get next recent touch of opposite ewt
        int lewt_index = -1;
        int sewt_index = -1;

        NextEWTTouchesForward(symb,(direction_change_index-1),lewt_index,sewt_index);
        if(opposite_touch_is_high)
        {
            // direction change in high, found opposite touch in low.
            // **************** (4) mark plot at low of index sewt_index
            date_time=iTime(symb,CONST_PERIOD,sewt_index);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            MM=TimeMinute(date_time);// Min
            SS=TimeSeconds(date_time);// Sec
            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Next low ewt touch: bar=%d Date=%d-%d_%d",sewt_index,MN,DD,HH));
            point4_date=StringFormat("%2dM-%2dD_%2dH-%2dM-%2dS",MN,DD,HH,MM,SS);
            // we would have entered LONG at direction change in high, and exited at next ewt touch on opposite side
            // is there profit?
            double entry_val= iHigh(symb,CONST_PERIOD,direction_change_index);
            double exit_val = iLow(symb,CONST_PERIOD,sewt_index);
            if(exit_val>entry_val)
            {
                profit=true;
            }
            else
            {
                profit=false;
            }

        }
        else
        {
            // direction change in low, found opposite touch in high.
            // **************** (4) mark plot at high of index lewt_index
            date_time=iTime(symb,CONST_PERIOD,lewt_index);
            MN=TimeMonth(date_time); // Month         
            DD=TimeDay(date_time);   // Day
            HH=TimeHour(date_time);  // Hour
            MM=TimeMinute(date_time);// Min
            SS=TimeSeconds(date_time);// Sec
            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Next low ewt touch: bar=%d Date=%d-%d_%d",lewt_index,MN,DD,HH));
            point4_date=StringFormat("%2dM-%2dD_%2dH-%2dM-%2dS",MN,DD,HH,MM,SS);
            // we would have entered SHORT at direction change in low, and exited at next ewt touch on opposite side
            // is there profit?
            double entry_val= iLow(symb,CONST_PERIOD,direction_change_index);
            double exit_val = iHigh(symb,CONST_PERIOD,lewt_index);
            if(exit_val<entry_val)
            {
                profit=true;
            }
            else
            {
                profit=false;
            }
        }
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Point 1 = %s",point1_date));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Point 2 = %s",point2_date));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Point 3 = %s",point3_date));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Point 4 = %s",point4_date));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("%s LTCT is in %s",symbol,(profit ? "PROFIT" : "LOSS")));

    }
    else
    {
        PrintMsg(DebugLogHandle,DB_MAX,"Couldn't detect direction change");
    }

    return 0;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* Find the index (bar) of price that set the current EWT value.
/* Must specify symbol, high (long) or low (short), and the start index*/
int GetEWTIndexFromIndex(string symb,int start_index,int HighLow)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("GetEWTIndexFromIndex called with\n symbol=%s\n start_index=%d\n HighLow=%d",symb,start_index,HighLow));

    int ewt_index=-1;
    if(HighLow==1)
    {
        ewt_index=iHighest(symb,CONST_PERIOD,MODE_HIGH,CONST_EWT_PERIOD,start_index);
    }
    else
    {
        ewt_index=iLowest(symb,CONST_PERIOD,MODE_LOW,CONST_EWT_PERIOD,start_index);
    }
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("GetEWTIndexFromIndex returned with\n ewt_index=%d",ewt_index));

    return ewt_index;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* Return the value of the EWT at a given index */
/* Must specify symbol, index and if the EWT returned is high (long) or low (short) */
double EWTValueAtIndex(string symbol,int start_index,int IsHigh)
{
    datetime date_time=iTime(symbol,CONST_PERIOD,start_index);
    int MN=TimeMonth(date_time); // Month         
    int DD=TimeDay(date_time);   // Day
    int HH=TimeHour(date_time);  // Hour
    int MM=TimeMinute(date_time);// Min
    int SS=TimeSeconds(date_time);// Sec
    //PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Found a touch on low: bar=%d\n Date=%d-%d_%d",bar,MN,DD,HH));

    // debug PrintMsg(DebugLogHandle,DB_MAX,StringFormat("EWTValueAtIndex called with %s, point 2=%d, Date=%d-%d_%d, Ishigh=%d",symbol,start_index,MN,DD,HH,IsHigh));

    int ewt_index=-1;
    double ewt_value=0.0;

    if(IsHigh==1)
    {
        ewt_index = iHighest(symbol,CONST_PERIOD,MODE_HIGH,CONST_EWT_PERIOD,start_index);
        ewt_value = iHigh(symbol,CONST_PERIOD,ewt_index);
    }
    else
    {
        ewt_index = iLowest(symbol,CONST_PERIOD,MODE_LOW,CONST_EWT_PERIOD,start_index);
        ewt_value = iLow(symbol,CONST_PERIOD,ewt_index);
    }
    //PrintMsg(DebugLogHandle,DB_MAX,StringFormat("EWTValueAtIndex returned ewt_value=%d",ewt_value));

    return ewt_value;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* Populate the arrays of high and low EWT values*/
void CalculateEWTValues(string symbol)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("CalculateEWTValues called with symbol %s",symbol));

    string highs= "";
    for(int bar = 0; bar<CONST_EWT_HISTORY_PERIOD; bar++)
    {
        int ewt_index=-1;
        ewt_index=iHighest(symbol,CONST_PERIOD,MODE_HIGH,CONST_EWT_PERIOD,bar);
        if(ewt_index>-1)
        {
            EWT_HIGH[bar]=ewt_index;
            highs+=StringFormat("[%d,%d]",bar,ewt_index);
        }
    }
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("CalculateEWTValues Highs = %s",highs));

    string lows = "";
    for(int bar = 0; bar < CONST_EWT_HISTORY_PERIOD; bar++)
    {
        int ewt_index=-1;
        ewt_index=iLowest(symbol,CONST_PERIOD,MODE_LOW,CONST_EWT_PERIOD,bar);
        if(ewt_index>-1)
        {
            EWT_LOW[bar]=ewt_index;
            lows+=StringFormat("[%d,%d]",bar,ewt_index);
        }
    }
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("CalculateEWTValues Lows = %s",lows));

    PrintMsg(DebugLogHandle,DB_MAX,"CalculateEWTValues returned");

}
/*--------------------------------------------------------------------------------------------------------------------*/
/* Return the indexes (bars) of the most recent (back in time) high and low EWt touches from a given symbol and start index */
void MostRecentEWTTouches(string symbol,int start_index,int &lewt_index,int &sewt_index)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("MostRecentEWTTouches called with\n symbol=%s\n start_index=%d\n lewt_index=%d, sewt_index=%d",symbol,start_index,lewt_index,sewt_index));

    // find most recent touch in highs
    string high_touches="high_touches:\n";
    for(int bar=0; bar<CONST_EWT_HISTORY_PERIOD; bar++)
    {
        // current bar value
        double bar_val=iHigh(symbol,CONST_PERIOD,bar);
        // value of ewt at bar
        double ewt_val=iHigh(symbol,CONST_PERIOD,EWT_HIGH[bar]);
        high_touches+=StringFormat("bar_val = %f, ewt_val = %f",bar_val,ewt_val);
        if(bar_val==ewt_val)
        {
            high_touches+=" touch";
            // this is a touch
            lewt_index=bar;
            // print out the date
            datetime date_time=iTime(symbol,CONST_PERIOD,bar);
            int MN=TimeMonth(date_time); // Month         
            int DD=TimeDay(date_time);   // Day
            int HH=TimeHour(date_time);  // Hour
            int MM=TimeMinute(date_time);// Min
            int SS=TimeSeconds(date_time);// Sec
            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Found a touch on high: bar=%d\n Date=%d-%d_%d-%m-%s",bar,MN,DD,HH,MM,SS));
            break;
        }
        PrintMsg(DebugLogHandle,DB_MAX,high_touches);
    }
    string low_touches="low_touches:\n";
    // find most recent touch in lows
    for(int bar=0; bar<365; bar++)
    {
        // current bar value
        double bar_val=iLow(symbol,CONST_PERIOD,bar);
        // value of ewt at bar
        double ewt_val=iLow(symbol,CONST_PERIOD,EWT_LOW[bar]);
        low_touches+=StringFormat("bar_val = %f, ewt_val = %f",bar_val,ewt_val);
        if(bar_val==ewt_val)
        {
            low_touches+=" touch";
            // this is a touch
            sewt_index=bar;
            // print out the date
            datetime date_time=iTime(symbol,CONST_PERIOD,bar);
            int MN=TimeMonth(date_time); // Month         
            int DD=TimeDay(date_time);   // Day
            int HH=TimeHour(date_time);  // Hour
            int MM=TimeMinute(date_time);// Min
            int SS=TimeSeconds(date_time);// Sec
            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Found a touch on low: bar=%d\n Date=%d-%d_%d-%m-%s",bar,MN,DD,HH,MM,SS));
            break;
        }
        PrintMsg(DebugLogHandle,DB_MAX,high_touches);
    }

    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("MostRecentEWTTouches returned with\n lewt_index=%d, sewt_index=%d",lewt_index,sewt_index));

}
/*--------------------------------------------------------------------------------------------------------------------*/
/*  Returns the next (forward in time) touches of the EWT indicator from a given index on a given symbol*/
void NextEWTTouchesForward(string symbol,int start_index,int &lewt_index,int &sewt_index)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("NextEWTTouchesForward called with\n symbol=%s\n start_index=%d\n lewt_index=%d, sewt_index=%d",symbol,start_index,lewt_index,sewt_index));
    // find most recent index in either high or lows where value = EWT value
    if(start_index<=0)
    {
        lewt_index = -1;
        sewt_index = -1;
        return;
    }
    for(int bar=start_index; bar>=0; bar--)
    {
        double bar_val=iHigh(symbol,CONST_PERIOD,bar);
        // value of ewt at bar
        double ewt_val=iHigh(symbol,CONST_PERIOD,EWT_HIGH[bar]);

        if(bar_val==ewt_val)
        {
            // this is a touch
            lewt_index=bar;
            // print out the date
            datetime date_time=iTime(symbol,CONST_PERIOD,bar);
            int MN=TimeMonth(date_time); // Month         
            int DD=TimeDay(date_time);   // Day
            int HH=TimeHour(date_time);  // Hour
            int MM=TimeMinute(date_time);// Min
            int SS=TimeSeconds(date_time);// Sec
            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Found a touch on high: bar=%d\n Date=%d-%d_%d-%m-%s",bar,MN,DD,HH,MM,SS));
            break;
        }
    }
    for(int bar=start_index; bar>=0; bar--)
    {
        // current bar value
        double bar_val=iLow(symbol,CONST_PERIOD,bar);
        // value of ewt at bar
        double ewt_val=iLow(symbol,CONST_PERIOD,EWT_LOW[bar]);

        if(bar_val==ewt_val)
        {
            // this is a touch
            sewt_index=bar;
            // print out the date
            datetime date_time=iTime(symbol,CONST_PERIOD,bar);
            int MN=TimeMonth(date_time); // Month         
            int DD=TimeDay(date_time);   // Day
            int HH=TimeHour(date_time);  // Hour
            int MM=TimeMinute(date_time);// Min
            int SS=TimeSeconds(date_time);// Sec
            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Found a touch on low: bar=%d\n Date=%d-%d_%d-%m-%s",bar,MN,DD,HH,MM,SS));
            break;
        }
    }
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("NextEWTTouchesForward returned with\n lewt_index=%d, sewt_index=%d",lewt_index,sewt_index));

}
/*--------------------------------------------------------------------------------------------------------------------*/
/* Given an index and a symbol, and long or short, trace back the EWT line and fnd the index at which the price 
 * changed from long to short or vice versa
 */
int FindIndexOfDirectionChangefromIndex(string symbol,int index,int IsHigh)
{
    datetime date_time=iTime(symbol,CONST_PERIOD,index);
    int MN=TimeMonth(date_time); // Month         
    int DD=TimeDay(date_time);   // Day
    int HH=TimeHour(date_time);  // Hour
    int MM=TimeMinute(date_time);// Min
    int SS=TimeSeconds(date_time);// Sec

    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("FindIndexOfDirectionChangefromIndex called with %s, point 2=%d, Date=%d-%d_%d-%d-%d, Ishigh=%d",symbol,index,MN,DD,HH,MM,SS,IsHigh));
    bool dir_change=false;
    int index_of_change=-1;
    if(IsHigh)
    {
        PrintMsg(DebugLogHandle,DB_MAX,"Finding direction change of high touch");

        // High
        // Get value of current touch
        double val=iHigh(symbol,CONST_PERIOD,index);
        int current_index=index;
        double prev_val=-1;
        while(!dir_change)
        {
            // get previous ewt value
            current_index++;
            prev_val=val;
            val=EWTValueAtIndex(symbol,current_index,IsHigh);
            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Is High = true, Traversing back through value %f at index %d, (prev=%f)",val,current_index,prev_val));
            if(val>prev_val)
            {
                // debug PrintMsg(DebugLogHandle,DB_MAX,"Trend on high is downwards");
                // trend is downward - can this even happen??
                // Does this mean that this point is the change of direction?
            }
            else if(val<prev_val)
            {
                PrintMsg(DebugLogHandle,DB_MAX,"Trend on high is upwards");
                // trend is upward
                // find when direction changed, looking back from here.
                // values on same trend will be < this value, find next > value

                while(!dir_change)
                {
                    prev_val=val;
                    // get previous ewt value
                    current_index++;
                    val=EWTValueAtIndex(symbol,current_index,IsHigh);
                    date_time=iTime(symbol,CONST_PERIOD,current_index);
                    MN=TimeMonth(date_time); // Month         
                    DD=TimeDay(date_time);   // Day
                    HH=TimeHour(date_time);  // Hour
                    MM=TimeMinute(date_time);// Min
                    SS=TimeSeconds(date_time);// Sec
                    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("debug current val = %f prev val = %f, current_index %d, Date=%d-%d_%d-%d-%d",val,prev_val,current_index,MN,DD,HH,MM,SS));
                    if(val>prev_val)
                    {
                        date_time=iTime(symbol,CONST_PERIOD,current_index);
                        MN=TimeMonth(date_time); // Month         
                        DD=TimeDay(date_time);   // Day
                        HH=TimeHour(date_time);  // Hour
                        MM=TimeMinute(date_time);// Min
                        SS=TimeSeconds(date_time);// Sec
                        PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Found 1st direction change at index %d, Date=%d-%d_%d-%d-%d, val=%f,now reversing",current_index,MN,DD,HH,MM,SS,val));
                        // found direction change, now reverse and find first upward breakout

                        while(!dir_change)
                        {
                            prev_val=val;
                            // get next ewt value
                            current_index--;
                            val=EWTValueAtIndex(symbol,current_index,IsHigh);
                            if(val>prev_val)
                            {
                                date_time=iTime(symbol,CONST_PERIOD,current_index);
                                MN=TimeMonth(date_time); // Month         
                                DD=TimeDay(date_time);   // Day
                                HH=TimeHour(date_time);  // Hour
                                MM=TimeMinute(date_time);// Min
                                SS=TimeSeconds(date_time);// Sec
                                PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Found 2nd direction change at index %d, Date=%d-%d_%d-%d-%d",current_index,MN,DD,HH,MM,SS));

                                // THIS IS POINT 3*****************
                                index_of_change=current_index;
                                dir_change=true;
                            }
                        }
                    }
                }
            }
            else
            {
                // same value
                prev_val=val;
            }
        }
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_MAX,"Finding direction change of low touch");

        // Low
        // Get value of current touch
        double val=iLow(symbol,CONST_PERIOD,index);
        int current_index=index;
        double prev_val=-1;
        while(!dir_change)
        {
            // get previous ewt value
            current_index++;
            prev_val=val;
            val=EWTValueAtIndex(symbol,current_index,IsHigh);
            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Is High = false, Traversing back through value %f at index %d, (prev=%f)",val,current_index,prev_val));
            if(val>prev_val)
            {
                PrintMsg(DebugLogHandle,DB_MAX,"Trend on low is downwards");
                // trend is upward
                // find when direction changed, looking back from here.
                // values on same trend will be > this value, find next < value

                while(!dir_change)
                {
                    prev_val=val;
                    // get previous ewt value
                    current_index++;
                    val=EWTValueAtIndex(symbol,current_index,IsHigh);
                    if(val<prev_val)
                    {
                        date_time=iTime(symbol,CONST_PERIOD,current_index);
                        MN=TimeMonth(date_time); // Month         
                        DD=TimeDay(date_time);   // Day
                        HH=TimeHour(date_time);  // Hour
                        MM=TimeMinute(date_time);// Min
                        SS=TimeSeconds(date_time);// Sec
                        PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Found 1st direction change at index %d, Date=%d-%d_%d-%d-%d, val=%f,now reversing",current_index,MN,DD,HH,MM,SS,val));
                        // found direction change, now reverse and find first upward breakout

                        while(!dir_change)
                        {
                            prev_val=val;
                            // get next ewt value
                            current_index--;
                            val=EWTValueAtIndex(symbol,current_index,IsHigh);
                            if(val<prev_val)
                            {
                                date_time=iTime(symbol,CONST_PERIOD,current_index);
                                MN=TimeMonth(date_time); // Month         
                                DD=TimeDay(date_time);   // Day
                                HH=TimeHour(date_time);  // Hour
                                MM=TimeMinute(date_time);// Min
                                SS=TimeSeconds(date_time);// Sec
                                PrintMsg(DebugLogHandle,DB_MAX,StringFormat("Found 2nd direction change at index %d, Date=%d-%d_%d-%d-%d",current_index,MN,DD,HH,MM,SS));

                                // THIS IS POINT 3*****************
                                index_of_change=current_index;
                                dir_change=true;
                            }
                        }
                    }
                }

            }
            else if(val<prev_val)
            {
                PrintMsg(DebugLogHandle,DB_MAX,"Trend on low is upwards");
                // trend is downward - can this even happen??
                // Does this mean that this point is the change of direction?
            }
            else
            {
                // same value
                prev_val=val;
            }
        }
    }
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("FindIndexOfDirectionChangefromIndex returned index %f, Date=%d-%d_%d",index_of_change,MN,DD,HH));
    return index_of_change;
}/*--------------------------------------------------------------------------------------------------------------------*/
/* For the given instrument details, calculate a new stop loss. 
 * Instrument must currently have an open trade with a valid ticket number
  */
bool CalcNewSLTP(Instrument &inst,Trade &trade)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("CalcNewSLTP called with\n instrument=%s \ntrade=%s",inst.AsString(),trade.AsString()));

    bool adjust_stoploss = false;
    // get current prices
    double last_tick_bid_price = 0.0;
    double last_tick_ask_price = 0.0;
    MqlTick last_tick;
    if(SymbolInfoTick(Symbol(),last_tick))
    {
        last_tick_bid_price = last_tick.bid;
        last_tick_ask_price = last_tick.ask;
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("SymbolInfoTick() failed, error = %s",GetLastError()));
        return false;
    }
    
    // has the price moved into profit enough?
    double ATR15=iATR(inst.symbol,CONST_PERIOD,15,0);
                       
    if(trade.trade_operation == TO_BUY)
    {
        if(last_tick_ask_price > (trade.open_price + (ATR15 * CONST_STOP_ADJUST_THRESHOLD)))
        {
            adjust_stoploss = true;
        }
    }
    else if(trade.trade_operation == TO_SELL)
    {
        if(last_tick_bid_price < (trade.open_price - (ATR15 * CONST_STOP_ADJUST_THRESHOLD)))
        {
            adjust_stoploss = true;
        }
    }
    
    
    if(adjust_stoploss)
    {
        // we have enough profit to move the stop loss
        double trade_price = 0.0;
        bool trade_placed = false;
        double RV=2*ATR15;
        double RV_pips= RV/inst.pip_location;
        double volume = 0;
        double ex_rate= 0;
    
        if(inst.base_currency_chart=="GBP")
        {
            ex_rate=1;
        }
        else
        {
            ex_rate=iClose(inst.base_currency_chart,CONST_PERIOD,0);
        }
    
        double AccBalance=AccountBalance()/100;
        double RV_money=(AccBalance/100)*ex_rate;
        double PIP_value=RV_money/RV_pips;
        double Trade_size=PIP_value/inst.pip_location;
        double Trade_size_MT4=Trade_size/inst.lot_size;
        double Trade_size_MT4_rounded=floor(Trade_size_MT4*100)/100; // round down to 2 decimal places
    
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: ATR15[%f]",ATR15));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: inst.base_currency_chart[%s]",inst.base_currency_chart));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: ex_rate[%f]",ex_rate));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: AccBalance[%f]",AccBalance));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: RV[%f]",RV));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: RV_pips[%f]",RV_pips));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: RV_money[%f]",RV_money));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: PIP_value[%f]",PIP_value));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: Trade_size[%f]",Trade_size));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: Trade_size_MT4[%f]",Trade_size_MT4));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: Trade_size_MT4_rounded[%f]",Trade_size_MT4_rounded));
    
    
        //*************************
        double price = 0;
        int slippage = 0;
        //*************************
        // Calculate StopLoss
        double stoploss=0;
        //*************************
        double takeprofit=0;
        double minstoplevel=MarketInfo(Symbol(),MODE_STOPLEVEL);
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: Minimum Stop Level=%f points",minstoplevel));
    
        if(trade.trade_type==TT_LEWT)
        {
            int lewt_index=-1;
            double lewt_value=-1;
            lewt_index=iHighest(inst.symbol,CONST_PERIOD,MODE_HIGH,CONST_EWT_PERIOD,0);
            if(lewt_index>-1)
            {
                lewt_value=iHigh(inst.symbol,CONST_PERIOD,lewt_index);
                if(lewt_value>-1)
                {
                    price=lewt_value;
                    stoploss    =   NormalizeDouble(price-RV-(minstoplevel*Point),Digits);
                    takeprofit  =   NormalizeDouble(price+RV+(minstoplevel*Point),Digits);
                    trade.stoploss = stoploss;
                    //trade.take_profit = takeprofit;
                }
            }
        }
        if(trade.trade_type==TT_SEWT)
        {
            int sewt_index=-1;
            double sewt_value=-1;
            sewt_index=iLowest(inst.symbol,CONST_PERIOD,MODE_LOW,CONST_EWT_PERIOD,0);
            if(sewt_index>-1)
            {
                sewt_value=iLow(inst.symbol,CONST_PERIOD,sewt_index);
                if(sewt_value>-1)
                {
                    price=sewt_value;
                    if(takeprofit<0){takeprofit=0;}
                    stoploss    =   NormalizeDouble(price+RV+(minstoplevel*Point),Digits);
                    takeprofit  =   NormalizeDouble(price-RV-(minstoplevel*Point),Digits);
                    trade.stoploss = stoploss;
                    //trade.take_profit = takeprofit;
                }
            }
        }
        
        
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: stop loss = %f, takeprofit = %f",stoploss, takeprofit));
    }

    return adjust_stoploss;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* For the given instrument details, place a pending order */
double MakePendingOrder(Instrument &inst,int ttype,Trade &placed_trade)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("MakePendingOrder called with\n instrument=%s ttype=%d",inst.AsString(),ttype));

    if(inst.GetNumTrades() >= CONST_MAX_ALLOW_TRADES)
    {
      PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: Returned. Maximum number of trades reached %d\n", CONST_MAX_ALLOW_TRADES));
      return 0.0;
    }
    double trade_price = 0.0;
    bool trade_placed = false;
    double ATR15=iATR(inst.symbol,CONST_PERIOD,15,0);
    double RV=2*ATR15;
    double RV_pips= RV/inst.pip_location;
    double volume = 0;
    double ex_rate= 0;

    if(inst.base_currency_chart=="GBP")
    {
        ex_rate=1;
    }
    else
    {
        ex_rate=iClose(inst.base_currency_chart,CONST_PERIOD,0);
    }

    double AccBalance=AccountBalance()/100;
    double RV_money=(AccBalance/100)*ex_rate;
    double PIP_value=RV_money/RV_pips;
    double Trade_size=PIP_value/inst.pip_location;
    double Trade_size_MT4=Trade_size/inst.lot_size;
    double Trade_size_MT4_rounded=floor(Trade_size_MT4*100)/100; // round down to 2 decimal places

    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: ATR15[%f]",ATR15));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: inst.base_currency_chart[%s]",inst.base_currency_chart));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: ex_rate[%f]",ex_rate));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: AccBalance[%f]",AccBalance));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: RV[%f]",RV));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: RV_pips[%f]",RV_pips));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: RV_money[%f]",RV_money));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: PIP_value[%f]",PIP_value));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: Trade_size[%f]",Trade_size));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: Trade_size_MT4[%f]",Trade_size_MT4));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: Trade_size_MT4_rounded[%f]",Trade_size_MT4_rounded));

    if(Trade_size_MT4_rounded==0)
    {
        PrintMsg(DebugLogHandle,DB_LOW,"MakePendingOrder: Returned. NO TRADE SIZE AVAILABLE");
        return 0.0;
    }
    //*************************
    double price = 0;
    int slippage = 0;
    //*************************
    // Calculate StopLoss
    double stoploss=0;
    //*************************
    double takeprofit=0;

    //--- get minimum stop level
   double minstoplevel=MarketInfo(Symbol(),MODE_STOPLEVEL);
   PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: Minimum Stop Level=%f points",minstoplevel));
    //--- calculated SL and TP prices must be normalized
   double min_buy_stoploss=NormalizeDouble(Bid-minstoplevel*Point,Digits);
   double min_buy_takeprofit=NormalizeDouble(Bid+minstoplevel*Point,Digits);

   
   
    if(ttype==TT_LEWT)
    {
        int lewt_index=-1;
        double lewt_value=-1;
        lewt_index=iHighest(inst.symbol,CONST_PERIOD,MODE_HIGH,CONST_EWT_PERIOD,0);
        if(lewt_index>-1)
        {
            lewt_value=iHigh(inst.symbol,CONST_PERIOD,lewt_index);
            if(lewt_value>-1)
            {
                price       =   lewt_value;
                if((price - Ask) < (minstoplevel*Point))
                {
                    price += minstoplevel*Point;
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Adjusted lewt price from %f to %f due to min stops",lewt_value,price));
                }
                stoploss    =   NormalizeDouble(price-RV-(minstoplevel*Point),Digits);
                takeprofit  =   NormalizeDouble(price+(RV*CONST_RV_MULTIPLIER)+(minstoplevel*Point),Digits);
                if(takeprofit<0){takeprofit=0;}
                
                string comment="jk_long_ewt";
                int ticket=OrderSend(inst.symbol,OP_BUYSTOP,Trade_size_MT4_rounded,price,0,stoploss,takeprofit,comment,0,0,clrWhite);
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: OrderSend:Symbol[%s],cmd[BUYSTOP],volume[%f],price[%f],slippage[0],stoploss[%f],takeprofit[%f],comment[%s],magic[0],expiration[0],color[clrGreen]",
                                                inst.symbol,Trade_size_MT4_rounded,price,stoploss,takeprofit,comment));

                if(ticket<0)
                {
                    int error=GetLastError();
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: OrderSend:Symbol[%s], ERROR placing trade: [%d] description: [%s]",
                                                inst.symbol,error,ErrorDescription(error)));
                    price = 0.0;
                }
                else
                {
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: OrderSend placed successfully. [%s] Ticket no:[%d]",comment,ticket));
                    trade_placed=true;
                    inst.lewt_trade=ticket;
                    //Trade trade;
                    placed_trade.Clear();
                    placed_trade.ticket_number=ticket;
                    placed_trade.symbol= inst.symbol;
                    placed_trade.open_price = price;
                    placed_trade.volume= Trade_size_MT4_rounded;
                    placed_trade.stoploss=stoploss;
                    placed_trade.take_profit=takeprofit;
                    placed_trade.comment=comment;
                    placed_trade.trade_type=TT_LEWT;
                    placed_trade.trade_operation = TO_BUYSTOP;
                    placed_trade.trade_state = TS_PENDING;
                    //WriteTradeLog(placed_trade);
                    trade_price=price;
                }
            }

        }
    }
     //--- calculated SL and TP prices must be normalized
   double min_sell_stoploss=NormalizeDouble(Ask-minstoplevel*Point,Digits);
   double min_sell_takeprofit=NormalizeDouble(Ask+minstoplevel*Point,Digits);
    if(ttype==TT_SEWT)
    {
        int sewt_index=-1;
        double sewt_value=-1;
        sewt_index=iLowest(inst.symbol,CONST_PERIOD,MODE_LOW,CONST_EWT_PERIOD,0);
        if(sewt_index>-1)
        {
            sewt_value=iLow(inst.symbol,CONST_PERIOD,sewt_index);
            if(sewt_value>-1)
            {
                price       =   sewt_value;
                if((Bid - price) < (minstoplevel*Point))
                {
                    price -= minstoplevel*Point;
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Adjusted sewt price from %f to %f due to min stops",sewt_value,price));
                }
                stoploss    =   NormalizeDouble(price+RV+(minstoplevel*Point),Digits);
                takeprofit  =   NormalizeDouble(price-(RV*CONST_RV_MULTIPLIER)-(minstoplevel*Point),Digits);
                if(takeprofit<0){takeprofit=0;}
                
                string comment="jk_short_ewt";
                int ticket=OrderSend(inst.symbol,OP_SELLSTOP,Trade_size_MT4_rounded,price,0,stoploss,takeprofit,comment,0,0,clrDarkOrange);
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: OrderSend:Symbol[%s],cmd[SELLSTOP],volume[%f],price[%f],slippage[0],stoploss[%f],takeprofit[%f],comment[%s],magic[0],expiration[0],color[clrGreen]",
                                                inst.symbol,Trade_size_MT4_rounded,price,stoploss,takeprofit,comment));

                if(ticket<0)
                {
                    int error=GetLastError();
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: OrderSend:Symbol[%s], ERROR placing trade: [%d] description: [%s]",
                                                inst.symbol,error,ErrorDescription(error)));
                                                
                    price = 0.0;
                }
                else
                {
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: OrderSend placed successfully. [%s] Ticket no:[%d]",comment,ticket));
                    trade_placed=true;
                    inst.sewt_trade=ticket;
                    //Trade trade;
                    placed_trade.Clear();
                    placed_trade.ticket_number=ticket;
                    placed_trade.symbol= inst.symbol;
                    placed_trade.open_price = price;
                    placed_trade.volume= Trade_size_MT4_rounded;
                    placed_trade.stoploss=stoploss;
                    placed_trade.take_profit=takeprofit;
                    placed_trade.comment=comment;
                    placed_trade.trade_type=TT_SEWT;
                    placed_trade.trade_operation = TO_SELLSTOP;
                    placed_trade.trade_state = TS_PENDING;
                    //WriteTradeLog(placed_trade);
                    trade_price=price;
                }
            }
        }
    }

    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("MakePendingOrder: returned trade_placed = %s",(trade_placed ? "true" : "false")));

    return trade_price = price;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* For the given symbol and trade type, find the indicator boundary and make a trade */
double MakeTrade(Instrument &inst,TradeType ttype)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("MakeTrade called with\n symbol=%s ltc period = %d ttype=%d",inst.symbol,ttype));
    //bool made_trade=false;
    double made_price=0.0;
    int index=-1;
    double value=-1;

    // LONG
    if(ttype==TT_LEWT || ttype==TT_LSMS)
    {
        int period = 0;
        if(ttype==TT_LEWT){ period = CONST_EWT_PERIOD; }
        if(ttype==TT_LSMS){ period = CONST_SMS_PERIOD; }
        
        // find bar with the highest high in period 'CONST_PERIOD'
        index=iHighest(inst.symbol,CONST_PERIOD,MODE_HIGH,period,0);
        if(index>-1)
        {
            // get the value of the highest high
            value=iHigh(inst.symbol,CONST_PERIOD,index);
            if(value>-1)
            {
                Trade new_trade;
                new_trade.Clear();
                made_price=MakePendingOrder(inst,ttype,new_trade);
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder returned made price = %f\n",made_price));
                if(made_price > 0.0)
                {
                    //WriteTradeLog(new_trade);
                    AddTrade(new_trade);   
                }
                else
                {
                    made_price=0.0;
                }
                
            }
            else
            {
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakeTrade: Symbol %s: error in value. iHigh returned -1, couldn't find value in ltct period.",inst.symbol));
                made_price=0.0;
            }
        }
        else
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakeTrade: Symbol %s: error in index. iHighest returned -1, couldn't find index in ltct period.",inst.symbol));
            made_price=0.0;
        }
    }

    // SHORT
    if(ttype==TT_SEWT || ttype==TT_SSMS)
    {
        int period = 0;
        if(ttype==TT_SEWT){ period = CONST_EWT_PERIOD; }
        if(ttype==TT_SSMS){ period = CONST_SMS_PERIOD; }
        
        // find the bar with the lowest low in period 'CONST_PERIOD'
        index=iLowest(inst.symbol,CONST_PERIOD,MODE_LOW,period,0);
        if(index>-1)
        {
            // get the value of the lowest low
            value=iLow(inst.symbol,CONST_PERIOD,index);
            if(value>-1)
            {
                Trade new_trade;
                new_trade.Clear();
                made_price=MakePendingOrder(inst,ttype,new_trade);
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder returned made price = %f\n",made_price));
                if(made_price > 0.0)
                {
                    //WriteTradeLog(new_trade);
                    AddTrade(new_trade);   
                }
                else
                {
                    made_price=0.0;
                }
            }
            else
            {
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakeTrade: Symbol %s: error in value. iHigh returned -1, couldn't find value in ltct period.",inst.symbol));
                made_price=0.0;
            }
        }
        else
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("OnStart: Symbol %s: error in index. iHighest returned -1, couldn't find index in ltct period.",inst.symbol));
            made_price=0.0;
        }
    }
    //PrintMsg(DebugLogHandle,DB_MAX,StringFormat("MakeTrade returned %s ",(made_trade ? "true" : "false")));
    return made_price; 
}
/*--------------------------------------------------------------------------------------------------------------------*/
int GetTradeIndexFromTicketNumber(int ticket_num)
{
    int trade_index = -1;
    // get trade info
    for(int index = 0; index < MAX_NUM_TRADES; index++)
    {
        if(Trades[index].ticket_number == ticket_num)
        {
            // found trade
            trade_index = index;
            break;
        }
    }
    if(trade_index == -1)
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("GetTradeIndexFromTicketNumber(): Error: Could not find trade index for ticket number %d",ticket_num));
    }
    return trade_index;
}
/*--------------------------------------------------------------------------------------------------------------------*/
// void CheckPlacedTrades()
// {
    // for (int index = 0; index < CONST_NUM_SYMBOLS; index++)
    // {
        // if(Instrs[index].lsms_trade > 0)
        // {
            // int ticket_no = Instrs[index].lsms_trade;
            // int trade_index = GetTradeIndexFromTicketNumber(ticket_no);

            // if(trade_index > -1 && Trades[trade_index].state != INVALID)
            // {
                // // operate on order, must 'select' it first
                // bool selected = OrderSelect(ticket_no,SELECT_BY_TICKET);
                // if(selected)
                // {
                    // // check the trade has the right symbol
                    // if(OrderSymbol() == Instrs[index].symbol)
                    // {
                        // datetime close_time = OrderCloseTime():
                        // if(close_time == 0)
                        // {
                            // // order is either pending or open
                            // int order_type = OrderType();
                            // if(order_type == OP_BUY || order_type == OP_SELL)
                            // {
                                // // order is open
                                // if (Trades[trade_index].state == PENDING)
                                // {
                                    // // trade was pending, now open
                                    // // record open price
                                    // Trades[trade_index].open_price = OpenOrderPrice();
                                    // // Trades[trade_index].comment;
                                    // Trades[trade_index].is_filled = true;
                                    // Trades[trade_index].trade_state = TS_OPEN;
                                    // PrintMsg(DebugLogHandle,DB_MAX,StringFormat("open price for the order ticket number %d = %f ",Trades[trade_index].open_price);

                                // }
                                // if (Trades[trade_index].trade_state == OPEN)
                                // {
                                    // // trade was open, still open
                                    // // adjust stop loss?
                                // }
                                // if (Trades[trade_index].trade_state == CLOSED || Trades[trade_index].trade_state == REPLACED)
                                // {
                                  // // trade state error!!!!
                                  // PrintMsg(DebugLogHandle,DB_MAX,"Trade error, trade is open but state is set CLOSED or REPLACED");
                                // }

                            // }
                            // else
                            // {
                                // if (Trades[trade_index].trade_state == PENDING)
                                // {
                                    // // order is still pending
                                    // // adjust ewt/sms values

                                // }

                            // }
                        // }
                        // else
                        // {
                            // // order is closed
                            // Trades[trade_index].open_price = OpenOrderPrice();
                            // // Trades[trade_index].comment;
                            // Trades[trade_index].is_filled = true;
                            // Trades[trade_index].state = OPEN;
                            // PrintMsg(DebugLogHandle,DB_MAX,StringFormat("open price for the order ticket number %d = %f ",Trades[trade_index].price);



                        // }
                    // }
                // }
                // else
                // {
                    // // order could not be selected
                    // PrintMsg("DebugLogHandle",StringFormat("Trade error, order could not be selected. OrderSelect returned the error of %s",GetLastError()));
                // }  
            // }
            



            
        // }
        // if(Instrs[index].lewt_trade > 0)
        // {
        // }
        // if(Instrs[index].sewt_trade > 0)
        // {
        // }
        // if(Instrs[index].ssms_trade > 0)
        // {
        // }
    // }

// }
/*--------------------------------------------------------------------------------------------------------------------*/
void AddTrade(Trade &other)
{
    bool trade_added = false;
    for (int index = 0; index < MAX_NUM_TRADES; index++)
    {
        if(Trades[index].trade_state == TS_INVALID)
        {
            //  found an empty trade
            Trades[index].Copy(other);
            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("AddTrade(): Added Trade %d at position %d",other.ticket_number,index));
            trade_added = true;
            break;
        }
    }
    // got to the end of trades array without finding a free space, so resize
    if(!trade_added)
    {
        MAX_NUM_TRADES = MAX_NUM_TRADES * 2;
        ArrayResize(Trades,MAX_NUM_TRADES);
        PrintMsg(DebugLogHandle,DB_MAX,StringFormat("AddTrade(): Resized Trades array to %d",MAX_NUM_TRADES));
        AddTrade(other);
    }
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("AddTrade(): There are now %d active trades", GetNumberActiveTrades()));
}
bool RemoveDeletedTrades()
{
    Trade temp_trades[];
    ArrayResize(temp_trades,MAX_NUM_TRADES);
    int temp_index = 0;
    int count_deleted = 0;
    int count_all = 0;
    // copy non deleted trades to temp array
    for(int index = 0; index < MAX_NUM_TRADES; index++)
    {
        if(Trades[index].trade_state != TS_INVALID)
        {
            count_all++;
            if(Trades[index].trade_state != TS_DELETED)
            {
                count_deleted++;
                temp_trades[temp_index].Copy(Trades[index]);
                temp_index++;
            }
            Trades[index].Clear();
        }
    }
    // now copy non-deleted trades back to resized array
    int count_preserved = 0;
    for(int index = 0; index < MAX_NUM_TRADES; index++)
    {
        if(temp_trades[index].trade_state != TS_INVALID)
        {
            count_preserved++;
            Trades[index].Copy(temp_trades[index]);
        }
    }
    bool result = false;
    if(count_preserved == (count_all-count_deleted))
    {
        result = true;
    }
    return result;
}
int GetNumberActiveTrades()
{
    int trade_count = 0;
    for(int index = 0; index < MAX_NUM_TRADES; ++index)
    {
        if(Trades[index].trade_state == TS_OPEN || Trades[index].trade_state == TS_PENDING)
        {
            trade_count++;
        }
    }
    return trade_count;
}
/*--------------------------------------------------------------------------------------------------------------------*/
// update trade
// returns trade index of ticket number
void CheckTrade(int trade_index, int instr_index)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("CheckTrade called with\n trade_index=%d instr_index=%d",trade_index,instr_index));
    int order_type = -1;
    
    // find out the trades current known status from trade log
    if(trade_index > -1 && 
       trade_index < MAX_NUM_TRADES && 
       Trades[trade_index].trade_state != TS_INVALID)
    {
    //*******************************************************************************************************************
        if(Trades[trade_index].trade_state == TS_PENDING)
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d was pending",
                Trades[trade_index].ticket_number));

            // Trade was last seen as PENDING, could now be either: still PENDING, OPEN or CLOSED
            // operate on order, must 'select' it first
            bool selected = OrderSelect(Trades[trade_index].ticket_number,SELECT_BY_TICKET);
            if(selected)
            {
                // check the trade has the right symbol
                if(OrderSymbol() == Instrs[instr_index].symbol)
                {
                    datetime close_time = OrderCloseTime();
                    if(close_time == 0)
                    {
                        // order is either pending or open
                        order_type = OrderType();
                        if(order_type > 0 && (order_type == OP_BUY || order_type == OP_SELL))
                        {
                            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d is now open",
                                Trades[trade_index].ticket_number));
                            // order is open
                            Trades[trade_index].open_price = OrderOpenPrice();
                            Trades[trade_index].open_time = OrderOpenTime();
                            Trades[trade_index].volume = OrderLots();
                            Trades[trade_index].stoploss = OrderStopLoss();
                            Trades[trade_index].take_profit = OrderTakeProfit();
                            Trades[trade_index].commission = OrderCommission();
                            Trades[trade_index].swap = OrderSwap();
                            Trades[trade_index].profit = OrderProfit();
                            Trades[trade_index].comment = OrderComment();
                            if(order_type == OP_BUY) { Trades[trade_index].trade_operation = TO_BUY; }
                            if(order_type == OP_SELL) { Trades[trade_index].trade_operation = TO_SELL; }
                            Trades[trade_index].is_filled = true;
                            Trades[trade_index].trade_state = TS_OPEN;
                            Trades[trade_index].last_price = OrderOpenPrice();
                            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("open price for the order ticket number %d = %f ",
                                Trades[trade_index].ticket_number,Trades[trade_index].open_price));
                            //WriteTradeLog(Trades[trade_index]);
                            
                            DrawOrderLine(Trades[trade_index]);
                            
                        }
                        else
                        {
                            // order is still pending 
                            // ATR will have changed, so recalc trade values
                            // delete and re-make order 
                            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Order with ticket number %d still pending, deleting and replacing trade",
                                Trades[trade_index].ticket_number));

                            bool deleted = OrderDelete(Trades[trade_index].ticket_number);
                            if(deleted)
                            {
                                Trades[trade_index].trade_state = TS_DELETED;
                                
                                //WriteTradeLog(Trades[trade_index]);
                                if(Trades[trade_index].trade_type == TT_LSMS) { Instrs[instr_index].lsms_trade = 0; }
                                if(Trades[trade_index].trade_type == TT_LEWT) { Instrs[instr_index].lewt_trade = 0; }
                                if(Trades[trade_index].trade_type == TT_SEWT) { Instrs[instr_index].sewt_trade = 0; }
                                if(Trades[trade_index].trade_type == TT_SSMS) { Instrs[instr_index].ssms_trade = 0; }
                                TradeType new_trade_type = Trades[trade_index].trade_type;
                                //RemoveDeletedTrades();
                                MakeTrade(Instrs[instr_index],new_trade_type);
                            }
                            
                        }
                    }
                    else
                    {
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d is now closed",Trades[trade_index].ticket_number));
                        // order is now closed
                        Trades[trade_index].close_price = OrderClosePrice();
                        Trades[trade_index].close_time = OrderCloseTime();
                        Trades[trade_index].volume = OrderLots();
                        Trades[trade_index].stoploss = OrderStopLoss();
                        Trades[trade_index].take_profit = OrderTakeProfit();
                        Trades[trade_index].commission = OrderCommission();
                        Trades[trade_index].swap = OrderSwap();
                        Trades[trade_index].profit = OrderProfit();
                        Trades[trade_index].comment = OrderComment();
                        Trades[trade_index].trade_state = TS_CLOSED;
                        PrintMsg(DebugLogHandle,DB_MAX,StringFormat("close price for the order ticket number %d = %f ",Trades[trade_index].ticket_number,Trades[trade_index].close_price));
                        
                        if(Trades[trade_index].trade_type == TT_LSMS) { Instrs[instr_index].lsms_trade = 0; }
                        if(Trades[trade_index].trade_type == TT_LEWT) { Instrs[instr_index].lewt_trade = 0; }
                        if(Trades[trade_index].trade_type == TT_SEWT) { Instrs[instr_index].sewt_trade = 0; }
                        if(Trades[trade_index].trade_type == TT_SSMS) { Instrs[instr_index].ssms_trade = 0; }
                        
                        // but the order went from pending to close,
                        // before we could update, so update now
                        Trades[trade_index].open_price = OrderOpenPrice();
                        Trades[trade_index].open_time = OrderOpenTime();
                        
                        order_type = OrderType();
                        if(order_type == OP_BUY) { Trades[trade_index].trade_operation = TO_BUY; }
                        if(order_type == OP_SELL) { Trades[trade_index].trade_operation = TO_SELL; }
                        Trades[trade_index].is_filled = true;
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order went from pending to close before update.. open price for the order ticket number %d = %f ",Trades[trade_index].ticket_number,Trades[trade_index].open_price));
                        //WriteTradeLog(Trades[trade_index]);
                        
                        DrawOrderLine(Trades[trade_index]);
                    }
                }
                else
                {
                    // order symbol mismatch
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, order does not have the same symbol as trade log, Log has %s, order has %s",Trades[trade_index].symbol,OrderSymbol()));
                }  
            }
            else
            {
                // order could not be selected
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, order could not be selected. OrderSelect returned the error of %s",GetLastError()));
            }  
        }
        // trade was previously OPEN
        if(Trades[trade_index].trade_state == TS_OPEN)
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d was open",Trades[trade_index].ticket_number));
            // operate on order, must 'select' it first
            bool selected = OrderSelect(Trades[trade_index].ticket_number,SELECT_BY_TICKET);
            if(selected)
            {
                // check the trade has the right symbol
                if(OrderSymbol() == Instrs[instr_index].symbol)
                {
                    datetime close_time = OrderCloseTime();
                    if(close_time == 0)
                    {
                        
                        // order is still open
                        order_type = OrderType();
                        if(order_type > 0 && (order_type == OP_BUY || order_type == OP_SELL))
                        {
                            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d is still open",Trades[trade_index].ticket_number));
                            // order is still open
                            //Trades[trade_index].open_price = OrderOpenPrice();
                            //Trades[trade_index].open_time = OrderOpenTime();
                            //Trades[trade_index].volume = OrderLots();
                            Trades[trade_index].stoploss = OrderStopLoss();
                            Trades[trade_index].take_profit = OrderTakeProfit();
                            Trades[trade_index].commission = OrderCommission();
                            Trades[trade_index].swap = OrderSwap();
                            Trades[trade_index].profit = OrderProfit();
                            //Trades[trade_index].comment = OrderComment();
                            if(order_type == OP_BUY) { Trades[trade_index].trade_operation = TO_BUY; }
                            if(order_type == OP_SELL) { Trades[trade_index].trade_operation = TO_SELL; }
                            Trades[trade_index].is_filled = true;
                            Trades[trade_index].trade_state = TS_OPEN;
                            //PrintMsg(DebugLogHandle,DB_MAX,StringFormat("open price for the order ticket number %d = %f ",ticket_num,Trades[trade_index].open_price);
                            
                            // *****************************************
                            // update the stop-loss in light of new ATR.


                            PrintMsg(DebugLogHandle,DB_LOW,"Checking SL/TP");
                            // make a dummy new trade just to calculate what the stoploss would be for a new trade
                            bool modify = CalcNewSLTP(Instrs[instr_index],Trades[trade_index]);
                            if(modify)
                            {
                                bool res = OrderModify(OrderTicket(),OrderOpenPrice(),Trades[trade_index].stoploss,Trades[trade_index].take_profit,0,0);
                                if(!res)
                                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Error in OrderModify. Error = %s",GetLastError()));
                                else
                                {
                                    PrintMsg(DebugLogHandle,DB_LOW,"Order modified successfully.");
                                    //Trades[trade_index].stoploss = new_stop_loss;
                                    //WriteTradeLog(Trades[trade_index]);
                                }  
                            }                   
                        }
                    }
                    else
                    {
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d is now closed",Trades[trade_index].ticket_number));
                        // order is now closed
                        Trades[trade_index].close_price = OrderClosePrice();
                        Trades[trade_index].close_time = OrderCloseTime();
                        Trades[trade_index].volume = OrderLots();
                        Trades[trade_index].stoploss = OrderStopLoss();
                        Trades[trade_index].take_profit = OrderTakeProfit();
                        Trades[trade_index].commission = OrderCommission();
                        Trades[trade_index].swap = OrderSwap();
                        Trades[trade_index].profit = OrderProfit();
                        Trades[trade_index].comment = OrderComment();
                        Trades[trade_index].trade_state = TS_CLOSED;
                        PrintMsg(DebugLogHandle,DB_MAX,StringFormat("close price for the order ticket number %d = %f ",Trades[trade_index].close_price));
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("profit on order ticket number %d was %f",Trades[trade_index].ticket_number,Trades[trade_index].profit ));
                        if(Trades[trade_index].trade_type == TT_LSMS) { Instrs[instr_index].lsms_trade = 0; }
                        if(Trades[trade_index].trade_type == TT_LEWT) { Instrs[instr_index].lewt_trade = 0; }
                        if(Trades[trade_index].trade_type == TT_SEWT) { Instrs[instr_index].sewt_trade = 0; }
                        if(Trades[trade_index].trade_type == TT_SSMS) { Instrs[instr_index].ssms_trade = 0; }
                        //WriteTradeLog(Trades[trade_index]);
                        
                        DrawOrderLine(Trades[trade_index]);
                    }
                }
                else
                {
                    // order does not have the correct symbol
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, order does not have the sam symbol as trade log Log has %s, order has %s",Trades[trade_index].symbol,OrderSymbol()));
                }  
            }
            else
            {
                // order could not be selected
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, order could not be selected. OrderSelect returned the error of %s",GetLastError()));
            }  
        }
        
        if(Trades[trade_index].trade_state == TS_CLOSED)
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, Instrument still has closed trade attached. Setting to zero",Trades[trade_index].ticket_number));
            if(Trades[trade_index].trade_type == TT_LSMS) { Instrs[instr_index].lsms_trade = 0; }
            if(Trades[trade_index].trade_type == TT_LEWT) { Instrs[instr_index].lewt_trade = 0; }
            if(Trades[trade_index].trade_type == TT_SEWT) { Instrs[instr_index].sewt_trade = 0; }
            if(Trades[trade_index].trade_type == TT_SSMS) { Instrs[instr_index].ssms_trade = 0; }
            //WriteTradeLog(Trades[trade_index]);
            DrawOrderLine(Trades[trade_index]);
        }
        
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, Trade index [%d] could not be found (couldn't find trade in local list) or trade is set as INVALID (never populated)",trade_index));
    }
    PrintMsg(DebugLogHandle,DB_MAX,"CheckTrade returned");
}
// Draw a line between the open and close points of a trade
bool DrawOrderLine(Trade &trade)
{
    bool res = false;
    int object_type = -1;
    string ticket_str = StringFormat("%d",trade.ticket_number);
    if(trade.trade_state == TS_OPEN)
    {
        object_type = OBJ_ARROW_UP;
        res = ObjectCreate(StringFormat("OPEN_%s",ticket_str),object_type,0,trade.open_time,trade.open_price);
    }
    else if(trade.trade_state == TS_CLOSED)
    {
        object_type = OBJ_ARROW_UP;
        res = ObjectCreate(StringFormat("CLOSE_%s",ticket_str),object_type,0,trade.close_time,trade.close_price);
        object_type = OBJ_ARROW_STOP;
        string trend_str = StringFormat("TREND_%s",ticket_str);
        res = ObjectCreate(trend_str,OBJ_TREND,0,trade.open_time,trade.open_price,trade.close_time,trade.close_price);
        //--- set line color 
        ObjectSetInteger(0,trend_str,OBJPROP_COLOR,clrOrange); 
        //--- set line display style 
        ObjectSetInteger(0,trend_str,OBJPROP_STYLE,STYLE_DASHDOT); 
        //--- set line width 
        ObjectSetInteger(0,trend_str,OBJPROP_WIDTH,1); 
        //--- display in the foreground (false) or background (true) 
        ObjectSetInteger(0,trend_str,OBJPROP_BACK,false); 
        //--- enable (true) or disable (false) the mode of moving the line by mouse 
        //--- when creating a graphical object using ObjectCreate function, the object cannot be 
        //--- highlighted and moved by default. Inside this method, selection parameter 
        //--- is true by default making it possible to highlight and move the object 
        ObjectSetInteger(0,trend_str,OBJPROP_SELECTABLE,false); 
        ObjectSetInteger(0,trend_str,OBJPROP_SELECTED,false); 
        //--- enable (true) or disable (false) the mode of continuation of the line's display to the right 
        ObjectSetInteger(0,trend_str,OBJPROP_RAY_RIGHT,false); 
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Error in DrawOrderLine. Invalid trade state passed. trade state = %d",trade.trade_state));
        return res;
    }

    if(!res)
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Error in DrawOrderLine. Error = %s",GetLastError()));
    }
    return res;
}
void PrintTradesList()
{
    PrintMsg(DebugLogHandle,DB_LOW,"PrintTradesList trades:");
    for(int index = 0; index < MAX_NUM_TRADES; index++)
    {
        if(Trades[index].trade_state != TS_INVALID)
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("%s",Trades[index].AsString()));
        }
    }
}
void ReadTradesFromAccount()
{
    //Clear trades array;
    for(int index = 0; index < MAX_NUM_TRADES; index++)
    {
        Trades[index].Clear();
    }
        
    // Get the number of market and pending orders
    int total=OrdersTotal();
    

    for(int pos=0;pos<total;pos++)
    {
        if(OrderSelect(pos,SELECT_BY_POS)==false)
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("ReadTradesFromAccount(): Error: Couldn't read trade info, Error %s",GetLastError()));
            continue;
        }
        TradeType type;
        if(OrderType() == OP_BUY || OrderType() == OP_BUYSTOP)
        {
            type = TT_LEWT;
        }
        else if(OrderType() == OP_SELL || OrderType() == OP_SELLSTOP)
        {
            type = TT_SEWT;
        }
        else
        {
            type = TT_INVALID;
        }
        TradeOperation op;
        if(OrderType() == OP_BUY)
        {
            op = TO_BUY;
        }
        else if(OrderType() == OP_BUYSTOP)
        {
            op = TO_BUYSTOP;
        }
        else if(OrderType() == OP_SELL)
        {
            op = TO_SELL;
        }
        else if(OrderType() == OP_SELLSTOP)
        {
            op = TO_SELLSTOP;
        }
        else
        {
            op = TO_INVALID;
        }
        bool open = false;
        if(OrderType() == OP_BUY || OrderType() == OP_SELL)
        {
            open = true;
        }
        TradeState state = TS_INVALID;
        if(open)
        {
            state = TS_OPEN;    
        }
        else if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP)
        {
            state = TS_PENDING;
        }

        Trades[pos].ticket_number = OrderTicket();
        Trades[pos].symbol = OrderSymbol();
        Trades[pos].open_price = OrderOpenPrice();
        Trades[pos].open_time = OrderOpenTime();
        Trades[pos].close_price = OrderClosePrice();
        Trades[pos].close_time = OrderCloseTime();
        Trades[pos].volume = OrderLots();
        Trades[pos].stoploss = OrderStopLoss();
        Trades[pos].take_profit = OrderTakeProfit();
        Trades[pos].commission = OrderCommission();
        Trades[pos].swap = OrderSwap();
        Trades[pos].profit = OrderProfit();
        Trades[pos].magic_number = OrderMagicNumber();
        Trades[pos].expiration_date = OrderExpiration();
        Trades[pos].comment = OrderComment();
        Trades[pos].trade_type = type;
        Trades[pos].trade_operation = op;
        Trades[pos].is_filled = open;
        Trades[pos].trade_state = state;
        Trades[pos].last_price = 0.0;
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("ReadTradesFromAccount(): Trade[%d]:%s",pos,Trades[pos].AsString()));
       
    }
}