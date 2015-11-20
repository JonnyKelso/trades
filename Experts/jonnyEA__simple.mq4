//+------------------------------------------------------------------+
//|                                                    jonnyEA_simple.mq4 |
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
// the length of the EWT period 
extern const int CONST_EWT_PERIOD = 21; 
const int CONST_SMS_PERIOD = 52;
// How much account balance % to risk per trade
extern const double CONST_TRADE_PERCENT_RISK = 1.0; 
 // take profit RV multiplier, used in calculating takeprofit
extern const double CONST_SL_ATR_MULTIPLIER = 2.0;  
// stop loss ATR multiplier, used in calculating stoploss
extern const double CONST_TP_ATR_MULTIPLIER = 1.0;  
// switch to toggel calculating of modified stop loss
//extern const bool CONST_USE_TRAILING_STOP = true;  
// num pips to SL
extern const int CONST_SL_PIPS = 10;
// num pips to TP
extern const int CONST_TP_PIPS = 10;

const int CONST_NUM_SYMBOLS = 17; 

Instrument Instrs[17];
Instrument CurrentInstrument;
int MAX_NUM_TRADES = 10;
Trade Trades[10];

const int CONST_MAX_ALLOW_TRADES = 2; // no more than this number of trades at any one time
const int CONST_PERIOD = Period();
const int CONST_EWT_HISTORY_PERIOD = 10000; // how many bars to go back in time when calculating EWT
int EWT_HIGH[10000]; // array for hiolding EWT high values
int EWT_LOW[10000]; // array for hiolding EWT low values

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
const int CONST_DEBUG_LEVEL = DB_LOW;

datetime last_run_datetime = 0;
datetime last_bar_open_at = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    FileClose(DebugLogHandle);
    DebugLogHandle=-1;
}

//+------------------------------------------------------------------+
// Opent he main output debug file and set the global file handle to it
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
// This is the function that is called on every tick received.
// 
//+------------------------------------------------------------------+
void OnTick()
{
    bool closeForWeekend = IsMarketClosingOrClosed();
    if(closeForWeekend)
    {
        // close all open trades
        CloseAllTrades();
    }
    else
    {
        // check time of latest bar against time of last checked bar
        if(last_bar_open_at != Time[0])
        {
            // print time now
            PrintFormat("------------------------- new bar found, time now = %s -----------------------",
                TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS));
            
            last_bar_open_at = Time[0];
            
        }
        Start();
    }

}
/*------------------------------------------------------------------
 * Script program start function                                    
 *------------------------------------------------------------------*/
void Start()
{
    int res = OpenDebugFile();
    if(res < 0)
    {
        Print("Error opening debug file");
        Alert("Error opening debug file");
        return;
    }

    // read logged instruments from file,
    // or reinitialise a list of empty instruments if no log file exists.
    int read_instrs_result = ReadInstrsLog();
    if(read_instrs_result < 0)
    {
        BuildInstrumentList();
    }
    //ReadTradesList();
    //ReadTradeLog();
    //PrintTradesList();
    
    // what symbol are we using, set the current Instrument.
    int instr_index = -1;
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Looking for Symbol %s",Symbol()));
    for(int index = 0; index < CONST_NUM_SYMBOLS; index++)
    {
        if(Instrs[index].symbol == Symbol())
        {
            instr_index = index;
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("********** %s ***************************************************\n%s\n",
                Instrs[instr_index].symbol,Instrs[instr_index].AsString()));
            CurrentInstrument.Copy(Instrs[instr_index]);
        }
    }
    if(instr_index < 0)
    {
        PrintMsg(DebugLogHandle,DB_LOW,"Could not find Symbol in Instruments list. Aborting.");
        Alert(StringFormat("Could not find Symbol [%s] in Instruments list. Aborting.",Symbol()));
        return;
    }
    
    // read current open and pending orders from account
    // (closed and deleted orders won't appear here)
    ReadTradesFromAccount();
    //CheckInstrumentTradeTickets(CurrentInstrument);
    // get ticket numbers for lewt and sewt trades
    //double ewt_long_price = 0.0;
    //double ewt_short_price = 0.0;
    int lewt_ticket_num = -1;
    int sewt_ticket_num = -1;
    for(int trade_index = 0; trade_index < MAX_NUM_TRADES; trade_index++)
    {
        if(Trades[trade_index].symbol == CurrentInstrument.symbol)
        {
            if(Trades[trade_index].trade_type == TT_LEWT)
            {
                CurrentInstrument.lewt_trade = Trades[trade_index].ticket_number;
            }
            else if(Trades[trade_index].trade_type == TT_SEWT)
            {
                CurrentInstrument.sewt_trade = Trades[trade_index].ticket_number;
            }
        }
    }

    
    //--- LEWT ---------------------------------------------------------
    // do we already have a trade here?
    if(CurrentInstrument.lewt_trade > 0)
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("OnStart: Checking LEWT trade for ticket #%d",
            CurrentInstrument.lewt_trade));
        int trade_index = GetTradeIndexFromTicketNumber(CurrentInstrument.lewt_trade);
        if(trade_index >= 0)
        {
            CheckTrade(Trades[trade_index]);
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
            int new_ticket = MakeTrade(CurrentInstrument,TT_LEWT);
            CurrentInstrument.lewt_trade = new_ticket;
        }
        else
        {
            PrintMsg(DebugLogHandle,DB_LOW,"OnStart: LEWT Reached CONST_MAX_ALLOW_TRADES limit");
        }
    }

    //--- SEWT ----------------------------------------------------------
    // do we already have a trade here?
    if(CurrentInstrument.sewt_trade > 0)
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("OnStart: Checking SEWT trade for ticket #%d",
            CurrentInstrument.sewt_trade));
        int trade_index = GetTradeIndexFromTicketNumber(CurrentInstrument.sewt_trade);
        if(trade_index >= 0)
        {
            CheckTrade(Trades[trade_index]);
        }
        
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_LOW,"OnStart: Making SHORT SEWT trade");
        // this is an empty trade slot
        // make new trade if possible
        if(GetNumberActiveTrades() < CONST_MAX_ALLOW_TRADES)
        {
            int new_ticket = MakeTrade(CurrentInstrument,TT_SEWT);
            CurrentInstrument.sewt_trade = new_ticket;
        }
        else
        {
            PrintMsg(DebugLogHandle,DB_LOW,"OnStart: SEWT Reached CONST_MAX_ALLOW_TRADES limit");
        }
    }
        
    //WriteInstrsList();
    //WriteTradesList();
    //FileClose(TradeLogHandle);
    //TradeLogHandle=-1;
    //FileClose(DebugLogHandle);
    //DebugLogHandle=-1;

  }
//+------------------------------------------------------------------+
void CheckInstrumentTradeTickets(Instrument &instr)
{
    
    int lewt_ticket = CurrentInstrument.lewt_trade;
    int sewt_ticket = CurrentInstrument.sewt_trade;
    bool found_lewt = false; 
    bool found_sewt = false;
    for(int index = 0; index < MAX_NUM_TRADES; index++)
    {
        if(Trades[index].ticket_number == lewt_ticket)
        {
            found_lewt = true;
        }
        if(Trades[index].ticket_number == sewt_ticket)
        {
            found_sewt = true;
        }
    }
    if(!found_lewt)
    {
        CurrentInstrument.lewt_trade = 0;
    }
    if(!found_sewt)
    {
        CurrentInstrument.sewt_trade = 0;
    }
    
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

    // initialisation of instruments 
    // not used in normal running, only used first time instruments are initialised 
    //                   Symbol         Base        Minimum  Lot         Pip         trade 
    //                                  Currency    Trade    Size        Location    tickets 
    //                                  Chart       Size 
    Instrument instr01("EURUSD^",       "GBPUSD",   0.01,    100000,     0.0001,     0,0,0,0);       //USD
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
    int result = -1;
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
        result = 0;
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_LOW,"ReadInstrsLog - Couldn't open Instruments log");
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
        if(Instrs[index].symbol == CurrentInstrument.symbol)
        {
            FileWriteString(InstrsLogHandle,CurrentInstrument.AsString());
        }
        else
        {
            FileWriteString(InstrsLogHandle,Instrs[index].AsString());
        }
        
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
    
    // has the price moved into profit enough?
    double ATR15    =iATR(inst.symbol,CONST_PERIOD,15,0);
    double RV       = CONST_SL_ATR_MULTIPLIER * ATR15;
    
    if(trade.trade_operation == TO_BUY)
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: Checking TO_BUY trade needs adjusting. Bid - OrderStoploss() = [%f] > RV = [%f]",
                (Bid - OrderStopLoss()), RV));
        if((Bid - OrderStopLoss()) > RV)
        {
            adjust_stoploss = true;
        }
    }
    else if(trade.trade_operation == TO_SELL)
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: Checking if TO_SELL trade needs adjusting. OrderStopLoss() - Ask = [%f] > RV = [%f]",
                (OrderStopLoss() - Ask), RV));
        if((OrderStopLoss() - Ask) > RV)
        {
            adjust_stoploss = true;
        }
    }
    else
    {
        Alert("CalcNewSLTP(): Invalid trade.trade_operation");
    }
    
    
    if(adjust_stoploss)
    {
        //*************************
        // Calculate StopLoss
        double stoploss=0;
        //*************************
        double takeprofit=0;
    
        double sl = 0.0;
        double tp = 0.0;
        GetSLTP(trade,inst,sl,tp);
        trade.stoploss = sl;
        trade.take_profit = tp;
     
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalcNewSLTP: open_price = [%f] stop loss = %f, takeprofit = %f",
            trade.open_price,trade.stoploss,trade.take_profit));
    }

    return adjust_stoploss;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* For the given instrument details, place a pending order */
int MakePendingOrder(Instrument &inst,Trade &trade)
{
    bool trade_placed = false;
    bool ok_to_trade = CalculateNewTradeValues(inst,trade);
    int cmd = -1;
    if(trade.trade_operation == TO_BUYSTOP)
    {
        cmd = OP_BUYSTOP;
    }
    else if(trade.trade_operation == TO_SELLSTOP)
    {
        cmd = OP_SELLSTOP;
    }
    else
    {
        Alert("MakePendingOrder(): Received trade has invalid trade operation");
        ok_to_trade = false;
        trade.ticket_number = -1;
    }
    
    if(ok_to_trade)
    {
        if((GetNumberActiveTrades() >= CONST_MAX_ALLOW_TRADES) && (cmd > -1))
        {
          PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: Returned. Maximum number of trades reached %d\n", CONST_MAX_ALLOW_TRADES));
        }
        else
        {
            int ticket = OrderSend(Symbol(),cmd,trade.volume,trade.open_price,0,trade.stoploss,trade.take_profit,trade.comment,0,0,clrWhite);
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: OrderSend:Symbol[%s],cmd[%d],volume[%f],price[%f],slippage[0],stoploss[%f],takeprofit[%f],comment[%s],magic[0],expiration[0],color[clrGreen]",
                                            Symbol(),trade.trade_operation,trade.volume,trade.open_price,trade.stoploss,trade.take_profit,trade.comment));
            
            if(ticket<0)
            {
                int error=GetLastError();
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: OrderSend:Symbol[%s], ERROR placing trade: [%d] description: [%s]",
                    Symbol(),error,ErrorDescription(error)));
                Alert(StringFormat("MakePendingOrder: OrderSend:Symbol[%s], ERROR placing trade: [%d] description: [%s]",
                    Symbol(),error,ErrorDescription(error)));
            }
            else
            {
                trade_placed = true;
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder: OrderSend placed successfully. [%s] Ticket no:[%d]",trade.comment,ticket));
                if(trade.trade_operation == TO_BUYSTOP){inst.lewt_trade=ticket;}
                if(trade.trade_operation == TO_SELLSTOP){inst.sewt_trade=ticket;}
                //Trade trade;
                trade.ticket_number=ticket;
                trade.open_price = 0.0;
            }
        
        }
    }
    

 
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("MakePendingOrder: returned trade_placed = %s",(trade_placed ? "true" : "false")));

    return trade.ticket_number;
}
/*--------------------------------------------------------------------------------------------------------------------*/
/* For the given symbol and trade type, find the indicator boundary and make a trade */
int MakeTrade(Instrument &inst,TradeType ttype)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("MakeTrade called with\n symbol=%s ltc period = %d ttype=%d",Symbol(),ttype));
    //bool made_trade=false;
    int trade_ticket=0;
    int index=-1;
    double value=-1;

    // LONG
    if(ttype==TT_LEWT || ttype==TT_LSMS)
    {
        int period = 0;
        if(ttype==TT_LEWT){ period = CONST_EWT_PERIOD; }
        if(ttype==TT_LSMS){ period = CONST_SMS_PERIOD; }
        
        // find bar with the highest high in period 'CONST_PERIOD'
        index=iHighest(Symbol(),CONST_PERIOD,MODE_HIGH,period,0);
        if(index>-1)
        {
            // get the value of the highest high
            value=iHigh(Symbol(),CONST_PERIOD,index);
            if(value>-1)
            {
                Trade new_trade;
                new_trade.Clear();
                new_trade.trade_operation = TO_BUYSTOP;
                new_trade.trade_type = TT_LEWT;
                new_trade.comment = "lewt";
                new_trade.open_price = 0.0;
                new_trade.symbol = Symbol();   
                trade_ticket = MakePendingOrder(inst,new_trade);
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder returned trade ticket = %d\n",trade_ticket));
                if(trade_ticket > 0)
                {
                    //WriteTradeLog(new_trade);
                    //AddTrade(new_trade);   
                }                
            }
            else
            {
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakeTrade: Symbol %s: error in value. iHigh returned -1, couldn't find value in ltct period.",Symbol()));
            }
        }
        else
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakeTrade: Symbol %s: error in index. iHighest returned -1, couldn't find index in ltct period.",Symbol()));
        }
    }

    // SHORT
    if(ttype==TT_SEWT || ttype==TT_SSMS)
    {
        int period = 0;
        if(ttype==TT_SEWT){ period = CONST_EWT_PERIOD; }
        if(ttype==TT_SSMS){ period = CONST_SMS_PERIOD; }
        
        // find the bar with the lowest low in period 'CONST_PERIOD'
        index=iLowest(Symbol(),CONST_PERIOD,MODE_LOW,period,0);
        if(index>-1)
        {
            // get the value of the lowest low
            value=iLow(Symbol(),CONST_PERIOD,index);
            if(value>-1)
            {
                Trade new_trade;
                new_trade.Clear();
                new_trade.trade_operation = TO_SELLSTOP;
                new_trade.trade_type = TT_SEWT;
                new_trade.comment = "sewt";
                trade_ticket=MakePendingOrder(inst,new_trade);
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakePendingOrder returned trade ticket = %d\n",trade_ticket));
                if(trade_ticket > 0.0)
                {
                    //WriteTradeLog(new_trade);
                    //AddTrade(new_trade);   
                }
            }
            else
            {
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("MakeTrade: Symbol %s: error in value. iHigh returned -1, couldn't find value in ltct period.",Symbol()));
            }
        }
        else
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("OnStart: Symbol %s: error in index. iHighest returned -1, couldn't find index in ltct period.",Symbol()));
        }
    }
    //PrintMsg(DebugLogHandle,DB_MAX,StringFormat("MakeTrade returned %s ",(made_trade ? "true" : "false")));
    return trade_ticket;
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
        Alert(StringFormat("GetTradeIndexFromTicketNumber(): Error: Could not find trade index for ticket number %d",ticket_num));
    }
    return trade_index;
}
void GetSLTP(Trade &trade,Instrument &inst, double &stoploss, double &takeprofit)
{
    // has the price moved into profit enough?
    double ATR15    = iATR(Symbol(),CONST_PERIOD,15,0);
    double RV       = CONST_SL_ATR_MULTIPLIER * ATR15;
    
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("GetSLTP: ATR15[%f]",ATR15));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("GetSLTP: RV[%f]",RV));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("GetSLTP: trade.open_price[%f]",trade.open_price));

    if(trade.trade_operation == TO_BUY || trade.trade_operation == TO_BUYSTOP )
    {
    //*********************
        //stoploss    =   trade.open_price - RV;
        //takeprofit  =   trade.open_price + NormalizeDouble(ATR15 * CONST_TP_ATR_MULTIPLIER,Digits);
    //*********************
        stoploss    =   trade.open_price - CONST_SL_PIPS*Point; // 10 pips
        takeprofit  =   trade.open_price + CONST_TP_PIPS*Point; // 10 pips

    //*********************
        //stoploss = trade.open_price - RV;
        //takeprofit = trade.open_price + RV;
        if(takeprofit < 0){ takeprofit = 0; }
    }
    else if(trade.trade_operation == TO_SELL  || trade.trade_operation == TO_SELLSTOP )
    {
    //*********************
        //stoploss    =   trade.open_price + RV;
        //takeprofit = trade.open_price - NormalizeDouble(ATR15 * CONST_TP_ATR_MULTIPLIER,Digits);
    //*********************
        stoploss    =   trade.open_price + CONST_SL_PIPS*Point; // 10 pips
        takeprofit  =   trade.open_price - CONST_TP_PIPS*Point; // 10 pips

    //*********************

    }
    else
    {
        Alert(StringFormat("GetSLTP(): invalid trade operation. Expected BUY/BUYSTOP, SELL/SELLSTOP, got [%d]",trade.trade_operation));
    }
     
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("GetSLTP: stoploss[%f] delta = [%f]",stoploss,CONST_SL_PIPS*Point ));
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("GetSLTP: takeprofit[%f] delta = [%f]",takeprofit,CONST_TP_PIPS*Point));
    
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
void CheckTrade(Trade &trade)
{
    PrintMsg(DebugLogHandle,DB_MAX,StringFormat("CheckTrade called with\n trade=%s",trade.AsString()));
    int order_type = -1;
    
    // find out the trades current known status 
    if(trade.ticket_number > 0 && trade.trade_state != TS_INVALID)
    {
    //*******************************************************************************************************************
        bool selected = OrderSelect(trade.ticket_number,SELECT_BY_TICKET);
        if(selected)
        {
            // check the trade has the right symbol
            if(OrderSymbol() == CurrentInstrument.symbol)
            {
                if(trade.trade_state == TS_PENDING)
                {
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d was pending",
                        trade.ticket_number));

                    // Trade was last seen as PENDING, could now be either: still PENDING, OPEN or CLOSED
                    datetime close_time = OrderCloseTime();
                    if(close_time == 0)
                    {
                        // order is either pending or open
                        order_type = OrderType();
                        if(order_type > 0 && (order_type == OP_BUY || order_type == OP_SELL))
                        {
                            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d is now open",
                                trade.ticket_number));
                            // order is open
                            trade.open_price = OrderOpenPrice();
                            trade.open_time = OrderOpenTime();
                            trade.volume = OrderLots();
                            trade.stoploss = OrderStopLoss();
                            trade.take_profit = OrderTakeProfit();
                            trade.commission = OrderCommission();
                            trade.swap = OrderSwap();
                            trade.profit = OrderProfit();
                            trade.comment = OrderComment();
                            if(order_type == OP_BUY) { trade.trade_operation = TO_BUY; }
                            if(order_type == OP_SELL) { trade.trade_operation = TO_SELL; }
                            trade.is_filled = true;
                            trade.trade_state = TS_OPEN;
                            trade.last_price = OrderOpenPrice();
                            PrintMsg(DebugLogHandle,DB_MAX,StringFormat("open price for the order ticket number %d = %f ",
                                trade.ticket_number,trade.open_price));
                            
                            //DrawOrderLine(trade);
                            // if current profit is above some threshold, move stoploss.
                            ModifyOpenOrder(CurrentInstrument,trade);
                            
                        }
                        else
                        {
                            // order is still pending 
                            // ATR will have changed, so recalc trade values
                            // delete and re-make order 
                            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Order with ticket number %d still pending, deleting and replacing trade",
                                trade.ticket_number));
                            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("number of trades = %d",
                                GetNumberActiveTrades()));
                            bool deleted = OrderDelete(trade.ticket_number);
                            if(deleted)
                            {
                                if(trade.trade_type == TT_LSMS) { CurrentInstrument.lsms_trade = 0; }
                                if(trade.trade_type == TT_LEWT) { CurrentInstrument.lewt_trade = 0; }
                                if(trade.trade_type == TT_SEWT) { CurrentInstrument.sewt_trade = 0; }
                                if(trade.trade_type == TT_SSMS) { CurrentInstrument.ssms_trade = 0; }
                                
                                trade.trade_state = TS_DELETED;
                                
                                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("number of trades = %d",
                                    GetNumberActiveTrades()));
                                //WriteTradeLog(trade);
                                TradeType new_trade_type = trade.trade_type;
                                //RemoveDeletedTrades();
                                int new_ticket = MakeTrade(CurrentInstrument,new_trade_type);
                                
                                if(trade.trade_type == TT_LSMS) { CurrentInstrument.lsms_trade = new_ticket; }
                                if(trade.trade_type == TT_LEWT) { CurrentInstrument.lewt_trade = new_ticket; }
                                if(trade.trade_type == TT_SEWT) { CurrentInstrument.sewt_trade = new_ticket; }
                                if(trade.trade_type == TT_SSMS) { CurrentInstrument.ssms_trade = new_ticket; }
                                
                                ReadTradesFromAccount();
                            }
                            
                        }
                    }
                    else
                    {
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d is now closed",trade.ticket_number));
                        // order is now closed
                        trade.close_price = OrderClosePrice();
                        trade.close_time = OrderCloseTime();
                        trade.volume = OrderLots();
                        trade.stoploss = OrderStopLoss();
                        trade.take_profit = OrderTakeProfit();
                        trade.commission = OrderCommission();
                        trade.swap = OrderSwap();
                        trade.profit = OrderProfit();
                        trade.comment = OrderComment();
                        trade.trade_state = TS_CLOSED;
                        PrintMsg(DebugLogHandle,DB_MAX,StringFormat("close price for the order ticket number %d = %f ",trade.ticket_number,trade.close_price));
                        
                        if(trade.trade_type == TT_LSMS) { CurrentInstrument.lsms_trade = 0; }
                        if(trade.trade_type == TT_LEWT) { CurrentInstrument.lewt_trade = 0; }
                        if(trade.trade_type == TT_SEWT) { CurrentInstrument.sewt_trade = 0; }
                        if(trade.trade_type == TT_SSMS) { CurrentInstrument.ssms_trade = 0; }
                        
                        // but the order went from pending to close,
                        // before we could update, so update now
                        trade.open_price = OrderOpenPrice();
                        trade.open_time = OrderOpenTime();
                        
                        order_type = OrderType();
                        if(order_type == OP_BUY) { trade.trade_operation = TO_BUY; }
                        if(order_type == OP_SELL) { trade.trade_operation = TO_SELL; }
                        trade.is_filled = true;
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order went from pending to close before update.. open price for the order ticket number %d = %f ",trade.ticket_number,trade.open_price));
                        //WriteTradeLog(trade);
                        
                        //DrawOrderLine(trade);
                    }
                }
                else if(trade.trade_state == TS_OPEN)
                {
                    // trade was previously OPEN
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d was open",trade.ticket_number));
                    datetime close_time = OrderCloseTime();
                    if(close_time == 0)
                    {
                        
                        // order is still open
                        order_type = OrderType();
                        if(order_type > 0 && (order_type == OP_BUY || order_type == OP_SELL))
                        {
                            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d is still open",trade.ticket_number));
                            // order is still open
                            //trade.open_price = OrderOpenPrice();
                            //trade.open_time = OrderOpenTime();
                            //trade.volume = OrderLots();
                            trade.stoploss = OrderStopLoss();
                            trade.take_profit = OrderTakeProfit();
                            trade.commission = OrderCommission();
                            trade.swap = OrderSwap();
                            trade.profit = OrderProfit();
                            //trade.comment = OrderComment();
                            if(order_type == OP_BUY) { trade.trade_operation = TO_BUY; }
                            if(order_type == OP_SELL) { trade.trade_operation = TO_SELL; }
                            trade.is_filled = true;
                            trade.trade_state = TS_OPEN;
                            //PrintMsg(DebugLogHandle,DB_MAX,StringFormat("open price for the order ticket number %d = %f ",ticket_num,trade.open_price);
                            
                            // *****************************************
                            // update the stop-loss in light of new ATR.
                            
                            
                            ModifyOpenOrder(CurrentInstrument,trade);
                        }
                    }
                    else
                    {
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("order ticket number %d is now closed",trade.ticket_number));
                        // order is now closed
                        trade.close_price = OrderClosePrice();
                        trade.close_time = OrderCloseTime();
                        trade.volume = OrderLots();
                        trade.stoploss = OrderStopLoss();
                        trade.take_profit = OrderTakeProfit();
                        trade.commission = OrderCommission();
                        trade.swap = OrderSwap();
                        trade.profit = OrderProfit();
                        trade.comment = OrderComment();
                        trade.trade_state = TS_CLOSED;
                        PrintMsg(DebugLogHandle,DB_MAX,StringFormat("close price for the order ticket number %d = %f ",trade.close_price));
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("profit on order ticket number %d was %f",trade.ticket_number,trade.profit ));
                        if(trade.trade_type == TT_LSMS) { CurrentInstrument.lsms_trade = 0; }
                        if(trade.trade_type == TT_LEWT) { CurrentInstrument.lewt_trade = 0; }
                        if(trade.trade_type == TT_SEWT) { CurrentInstrument.sewt_trade = 0; }
                        if(trade.trade_type == TT_SSMS) { CurrentInstrument.ssms_trade = 0; }
                        //WriteTradeLog(trade);
                        
                        //DrawOrderLine(trade);
                    }
                }
                else if(trade.trade_state == TS_CLOSED)
                {
                    PrintMsg(DebugLogHandle,DB_LOW,"Trade error, Instrument still has closed trade attached. Setting to zero");
                    if(trade.trade_type == TT_LSMS) { CurrentInstrument.lsms_trade = 0; }
                    if(trade.trade_type == TT_LEWT) { CurrentInstrument.lewt_trade = 0; }
                    if(trade.trade_type == TT_SEWT) { CurrentInstrument.sewt_trade = 0; }
                    if(trade.trade_type == TT_SSMS) { CurrentInstrument.ssms_trade = 0; }
                    //WriteTradeLog(trade);
                    //DrawOrderLine(trade);
                }
                else
                {
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, Trade state is not valid {trade state = %d)",trade.trade_state));
                    Alert(StringFormat("Trade error, Trade state is not valid {trade state = %d)",trade.trade_state));

                }
            }
            else
            {
                // order symbol mismatch
                PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, order does not have the same symbol as current instrument. Current Instr has %s, order has %s",CurrentInstrument.symbol,OrderSymbol()));
                Alert(StringFormat("Trade error, order does not have the same symbol as current instrument. Current Instr has %s, order has %s",CurrentInstrument.symbol,OrderSymbol()));
            }  
        }
        else
        {
            // order could not be selected
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, order could not be selected. OrderSelect returned the error of %s",GetLastError()));
            Alert(StringFormat("Trade error, order could not be selected. OrderSelect returned the error of %s",GetLastError()));
        } 
        
        
    }
    else
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Trade error, Trade [%d] could not be found (couldn't find trade in local list) or trade is set as INVALID (never populated)",trade.ticket_number));
        Alert(StringFormat("Trade error, Trade [%d] could not be found (couldn't find trade in local list) or trade is set as INVALID (never populated)",trade.ticket_number));
    }
    PrintMsg(DebugLogHandle,DB_MAX,"CheckTrade returned");
}
int ModifyOpenOrder(Instrument &instr, Trade &trade)
{
    int result = -1;
    
    PrintMsg(DebugLogHandle,DB_LOW,"ModifyOpenOrder(): Checking SL/TP");
                            
    // make a dummy new trade just to calculate what the stoploss would be for a new trade
    bool modify = CalcNewSLTP(instr,trade);
    if(modify)
    {
        bool res = OrderModify(OrderTicket(),OrderOpenPrice(),trade.stoploss,trade.take_profit,0,0);
        if(!res)
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Error in OrderModify. Error = %s",GetLastError()));
            Alert(StringFormat("Error in OrderModify. Error = %s",GetLastError()));
        }
        else
        {
            PrintMsg(DebugLogHandle,DB_LOW,"Order modified successfully.");
            //trade.stoploss = new_stop_loss;
            //WriteTradeLog(trade);
            result = 0;
        }  
    }  
    return result;
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
            Alert(StringFormat("ReadTradesFromAccount(): Error: Couldn't read trade info, Error %s",GetLastError()));
            continue;
        }
        TradeType type;
        TradeOperation op;
        TradeState state = TS_INVALID;
        if(OrderType() == OP_BUY)
        {
            type = TT_LEWT;
            op = TO_BUY;
            state = TS_OPEN;
        }
        else if(OrderType() == OP_SELL)
        {
            type = TT_SEWT;
            op = TO_SELL;
            state = TS_OPEN;
        }
        else if(OrderType() == OP_BUYSTOP)
        {
            type = TT_LEWT;
            op = TO_BUYSTOP;
            state = TS_PENDING;
        }
        else if(OrderType() == OP_SELLSTOP)
        {
            type = TT_SEWT;
            op = TO_SELLSTOP;
            state = TS_PENDING;
        }
        else
        {
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("ReadTradesFromAccount(): Error: Order type [%d] not recognised. %d",OrderType()));
            Alert(StringFormat("ReadTradesFromAccount(): Error: Order type [%d] not recognised. %d",OrderType()));
            type = TT_INVALID;
            op = TO_INVALID;
            state = TS_INVALID;
        }
        
        if(state != TS_INVALID)
        {
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
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
            {
                Trades[pos].is_filled = true;
            }
            else
            {
                Trades[pos].is_filled = false;
            }
            
            Trades[pos].trade_state = state;
            Trades[pos].last_price = 0.0;
            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("ReadTradesFromAccount(): Trade[%d]:%s",pos,Trades[pos].AsString()));
        }


    }
}
bool CalculateNewTradeValues(Instrument &inst, Trade &trade)
{
    bool values_ok = true;
    
    //--- get minimum lot size
    double mrkt_lot_size=MarketInfo(Symbol(),MODE_LOTSIZE);
    double mrkt_lot_min=MarketInfo(Symbol(),MODE_MINLOT);
    double mrkt_lot_max=MarketInfo(Symbol(),MODE_MAXLOT);
    double mrkt_lot_step=MarketInfo(Symbol(),MODE_LOTSTEP);
    double mrkt_min_stop_level=MarketInfo(Symbol(),MODE_STOPLEVEL);
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: Market: symbol = %s, lot size=[%f],min lot size=[%f], max lot size=[%f], lot step=[%f], min stop level=[%f]",
      Symbol(), mrkt_lot_size,mrkt_lot_min,mrkt_lot_max,mrkt_lot_step,mrkt_min_stop_level));
      
    // Account balance in GBP
    double AccBalance=AccountBalance();  // balance in pounds
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: AccBalance[%f]",AccBalance));
    // latest ATR15 value
    double ATR15=iATR(inst.symbol,CONST_PERIOD,15,0);
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: ATR15[%f]",ATR15));
    // relative volatility, our max risk.
    double RV = CONST_SL_ATR_MULTIPLIER * ATR15;
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: max risk RV[%f] (CONST_RV_MULITIPLIER * ATR)",RV));
    // our risk in pips is RV_pips
    double RV_pips= 10;//RV/inst.pip_location;
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: max risk in pips RV_pips[%f]",RV_pips));

    double ex_rate= 0;
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: base currency chart[%s]",inst.base_currency_chart));
    if(inst.base_currency_chart=="GBP")
    {
        ex_rate=1;
    }
    else
    {
        ex_rate=Close[0];
    }
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: ex_rate[%f]",ex_rate));

    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: AccBalance[%f]",AccBalance));
    // max amount to risk per trade in GBP  
    double risk_money = AccBalance*(CONST_TRADE_PERCENT_RISK/100.0);
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: risk_money[%f], [%f] percent of Acc",risk_money,CONST_TRADE_PERCENT_RISK));
    
    // max amount to risk in base currency
    double risk_money_in_base_curr = risk_money*ex_rate;
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: risk_money_in_base_curr[%f], rate = [%f]",risk_money_in_base_curr,ex_rate));
    
    double RV_money=((ex_rate > 0) ? risk_money_in_base_curr : 0.0);
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: RV_money[%f]",RV_money));
    
    // amount of cash per pip, based on our risk in cash and risk in pips
    double PIP_value=((RV_pips >0)?(RV_money/RV_pips):0.0);
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: cash per pip PIP_value[%f]",PIP_value));
    // trade size in pips
    double Trade_size=PIP_value/inst.pip_location;
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: Trade_size in pips[%f]",Trade_size));
    // trade size in lots
    double Trade_size_MT4=Trade_size/inst.lot_size;
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: Trade_size_MT4 in lots[%f]",Trade_size_MT4));
    // trade size rounded to MT4 values
    double Trade_size_MT4_rounded=floor(Trade_size_MT4*(1/mrkt_lot_min))/(1/mrkt_lot_min); // round down to 2 decimal places
    if(Trade_size_MT4_rounded > mrkt_lot_max){Trade_size_MT4_rounded = mrkt_lot_max;}
    //if(Trade_size_MT4_rounded == 0){Trade_size_MT4_rounded = mrkt_lot_min;}
    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: Trade_size_MT4_rounded to MT4 values[%f]",Trade_size_MT4_rounded));
        
    //*************************
    double price = 0;
    double stoploss=0;
    double takeprofit=0;
    if(Trade_size_MT4_rounded==0)
    {
        PrintMsg(DebugLogHandle,DB_LOW,"CalculateNewTradeValues: Returned. NO TRADE SIZE AVAILABLE");
        values_ok = false;
    }
    else
    {
        //--- get minimum stop level
        //--- calculated SL and TP prices must be normalized
        double min_buy_stoploss=NormalizeDouble(Ask - (mrkt_min_stop_level*Point),Digits);
        double min_buy_takeprofit=NormalizeDouble(Ask + (mrkt_min_stop_level*Point),Digits);
               
        if(trade.trade_operation==TO_BUYSTOP)
        {
            int lewt_index=-1;
            double lewt_value=-1;
            lewt_index=iHighest(Symbol(),CONST_PERIOD,MODE_HIGH,CONST_EWT_PERIOD,0);
            if(lewt_index>-1)
            {
                lewt_value=iHigh(Symbol(),CONST_PERIOD,lewt_index);
                if(lewt_value>-1)
                {
                    price       =   lewt_value;
                    // check open price isn't too close to current price
                    if((price-Ask) < NormalizeDouble(mrkt_min_stop_level*Point,Digits))
                    {
                        price = Ask + NormalizeDouble(mrkt_min_stop_level*Point,Digits);
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues(): Adjusted lewt price from %f to %f due to min stops. Ask[%f] Bid[%f]",lewt_value,price,Ask,Bid));
                        Alert(StringFormat("CalculateNewTradeValues(): Adjusted lewt price from %f to %f due to min stops. Ask[%f] Bid[%f]",lewt_value,price,Ask,Bid));
                    }
                    //stoploss    =   NormalizeDouble(price-RV,Digits); //-(mrkt_min_stop_level*Point),Digits);
                    //takeprofit  =   NormalizeDouble(price+(RV*CONST_RV_MULTIPLIER),Digits);//+(mrkt_min_stop_level*Point),Digits);
                    //stoploss = price - CONST_SL_PIPS*Point; // 10 pips
                    //takeprofit = price + CONST_TP_PIPS*Point;
                    //stoploss = GetStopLoss();
                    //takeprofit = GetTakeProfit();
                    //PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues(): Normalised stoploss = [%f], unnormalised stoploss = [%f]",stoploss,price-RV));
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues(): Normalised price = [%f], unnormalised price = [%f]",price,lewt_value));

                    //if(takeprofit<0){takeprofit=0;}
                }
            }
        }
         //--- calculated SL and TP prices must be normalized
        double min_sell_stoploss=NormalizeDouble(Bid - (mrkt_min_stop_level*Point),Digits);
        double min_sell_takeprofit=NormalizeDouble(Bid + (mrkt_min_stop_level*Point),Digits);
        if(trade.trade_operation==TO_SELLSTOP)
        {
            int sewt_index=-1;
            double sewt_value=-1;
            sewt_index=iLowest(Symbol(),CONST_PERIOD,MODE_LOW,CONST_EWT_PERIOD,0);
            if(sewt_index>-1)
            {
                sewt_value=iLow(Symbol(),CONST_PERIOD,sewt_index);
                if(sewt_value>-1)
                {
                    price       =  sewt_value;
                    // check open price isn't too close to current price
                    if((Bid - price) < NormalizeDouble(mrkt_min_stop_level*Point,Digits))
                    {
                        price = Bid - NormalizeDouble(mrkt_min_stop_level*Point,Digits);
                        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("Adjusted sewt price from %f to %f due to min stops. Ask[%f] Bid[%f]",sewt_value,price,Ask,Bid));
                        Alert(StringFormat("Adjusted sewt price from %f to %f due to min stops. Ask[%f] Bid[%f]",sewt_value,price,Ask,Bid));
                    }
                    //stoploss    =   NormalizeDouble(price+RV,Digits);//+(mrkt_min_stop_level*Point),Digits);
                    //takeprofit  =   NormalizeDouble(price-(RV*CONST_RV_MULTIPLIER),Digits);//-(mrkt_min_stop_level*Point),Digits);
                    //stoploss = price + CONST_SL_PIPS*Point; // 10 pips
                    //takeprofit = price - CONST_TP_PIPS*Point;
                    //stoploss = GetStopLoss();
                    //takeprofit = GetTakeProfit();
                    //if(takeprofit<0){takeprofit=0;}
                    PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues(): Normalised price = [%f], unnormalised price = [%f]",price,sewt_value));

                }
            }
        }
        double sl = 0.0;
        double tp = 0.0;
        trade.open_price = price;
        GetSLTP(trade,inst,sl,tp);
        stoploss = sl;
        takeprofit = tp;
        if(stoploss <= 0.0 || takeprofit <= 0.0)
        {
            values_ok = false; // no trade without stops
            price = 0;
            stoploss=0;
            takeprofit=0;
        }
        if(trade.trade_type == TT_LEWT)
        {
            double this_trade_risk = (price - stoploss) * PIP_value;
            Alert(StringFormat("LEWT trade has risk [%f]",this_trade_risk));
            if(this_trade_risk > risk_money)
            {
                Alert(StringFormat("LEWT trade has risk greater than %f% of Account balance (balance = [%f], current risk = [%f] (%f %))",
                    CONST_TRADE_PERCENT_RISK,AccBalance,this_trade_risk,(this_trade_risk/AccBalance)*100));
                values_ok = false;
                price = 0;
                stoploss=0;
                takeprofit=0;
            }
        }
        if(trade.trade_type == TT_SEWT)
        {
            double this_trade_risk = (stoploss - price) * PIP_value;
            Alert(StringFormat("SEWT trade has risk [%f]",this_trade_risk));
            if(this_trade_risk > risk_money)
            {
                Alert(StringFormat("SEWT trade has risk greater than %d % of Account balance (balance = [%f], current risk = [%f] (%f %))",
                    CONST_TRADE_PERCENT_RISK,AccBalance,this_trade_risk,(this_trade_risk/AccBalance)*100));
                values_ok = false;
                price = 0;
                stoploss=0;
                takeprofit=0;
            }
        }
    }
    if(values_ok)
    {
    
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: price[%f]",price));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: stoploss[%f]",stoploss));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: takeprofit[%f]",takeprofit));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: volume[%f]",Trade_size_MT4_rounded));
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CalculateNewTradeValues: Ask[%f],Bid[%f]",Ask,Bid));
    
        trade.volume = Trade_size_MT4_rounded;
        trade.open_price = price;
        trade.stoploss = stoploss;
        trade.take_profit = takeprofit;   
    }
    

    return values_ok;
}
bool IsMarketClosingOrClosed()
{
    bool closingorclosed = false;
    // do not work on holidays. 
    // Current zero-based day of the week (0-Sunday,1,2,3,4,5,6).
    if(DayOfWeek()==0 || DayOfWeek()==6)
    {
        closingorclosed = true;
    }
    else if(DayOfWeek()==5)
    {
        // Its Friday, are we approaching market close?
        datetime date_time=TimeLocal();
        int HH=TimeHour(date_time);
        if(HH >=12)
        {
            closingorclosed = true;
        }
    }

    return closingorclosed;
}
void CloseAllTrades()
{
    // Get the number of market and pending orders
    int active_orders = OrdersTotal();

    while(active_orders > 0)
    {
        PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CloseAllTrades(): Closing [%d] orders",active_orders));
        for(int pos = 0; pos < active_orders; pos++)
        {
            bool result = false;
            if(OrderSelect(pos,SELECT_BY_POS))
            {
                double ask , bid;
                RefreshRates();
                ask = NormalizeDouble(MarketInfo(OrderSymbol(),MODE_ASK),(int)MarketInfo(OrderSymbol(),MODE_DIGITS));
                bid = NormalizeDouble(MarketInfo(OrderSymbol(),MODE_BID),(int)MarketInfo(OrderSymbol(),MODE_DIGITS));
                
                if(OrderType()==OP_BUY)
                {
                    for(int tries = 0; tries < 100; tries++)
                    {
                        result = OrderClose(OrderTicket(),OrderLots(),bid,3,Violet);
                        if(result==true) 
                        {
                            break; 
                        }
                        else
                        {
                            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CloseAllTrades(): Couldn't close order [%d], retrying [%d]",OrderTicket(),tries));
                            Sleep(500);
                            RefreshRates();
                            ask = NormalizeDouble(MarketInfo(OrderSymbol(),MODE_ASK),(int)MarketInfo(OrderSymbol(),MODE_DIGITS));
                            bid = NormalizeDouble(MarketInfo(OrderSymbol(),MODE_BID),(int)MarketInfo(OrderSymbol(),MODE_DIGITS));      
                        }
                    }
                    
                }
                if(OrderType()==OP_SELL)
                {
                    for(int tries = 0; tries < 100; tries++)
                    {
                        result = OrderClose(OrderTicket(),OrderLots(),ask,3,Violet);
                        if(result==true) 
                        {
                            break; 
                        }
                        else
                        {
                            PrintMsg(DebugLogHandle,DB_LOW,StringFormat("CloseAllTrades(): Couldn't close order [%d], retrying [%d]",OrderTicket(),tries));                        
                            Sleep(500);
                            RefreshRates();
                            ask = NormalizeDouble(MarketInfo(OrderSymbol(),MODE_ASK),(int)MarketInfo(OrderSymbol(),MODE_DIGITS));
                            bid = NormalizeDouble(MarketInfo(OrderSymbol(),MODE_BID),(int)MarketInfo(OrderSymbol(),MODE_DIGITS));  
                        }
                    }
                }
            }
            
        }
        active_orders = OrdersTotal();
    }
}
