//+------------------------------------------------------------------+
//|                                                        Trade.mqh |
//|                                      Copyright 2015, Jonny kelso |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Jonny kelso"
#property link      "http://www.mql4.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum TradeType
{
    TT_INVALID = 0x0,
    TT_LSMS    = 0x1,
    TT_LEWT    = 0x2,
    TT_SEWT    = 0x4,
    TT_SSMS    = 0x8
};
enum TradeState
{
    TS_INVALID,
    TS_PENDING,
    TS_OPEN,
    TS_CLOSED,
    TS_DELETED
};
enum TradeOperation
{
    TO_INVALID,
    TO_BUY,
    TO_SELL,         // - sell order,
    TO_BUYLIMIT,     // - buy limit pending order,
    TO_BUYSTOP,      // - buy stop pending order,
    TO_SELLLIMIT,    // - sell limit pending order,
    TO_SELLSTOP      // - sell stop pending order.
};

class Trade
{
private:

public:
       Trade();
       Trade(  int ticket_num,
               string symb,
               double oprice,
               datetime otime,
               double cprice,
               datetime ctime,
               double vol,
               double sloss,
               double tprofit,
               double comm,
               double swp,
               double prft,
               double magic_num,
               datetime exp_date,
               string cmmnt,
               TradeType ttype,  
               TradeOperation toperation,
               bool filled,
               TradeState tstate,
               double lastprice
            );

      ~Trade();

      string AsString();
      void Clear();
      void Copy(Trade &other);
      void Trade::SetTradeType(string str);
      void Trade::SetTradeOperation(string str);
      void Trade::SetTradeState(string str);
      void Trade::SetIsFilled(string str);            
      
      int ticket_number;
      string symbol;
      double open_price;
      datetime open_time;
      double close_price;
      datetime close_time;
      double volume;
      double stoploss;
      double take_profit;
      double commission;
      double swap;
      double profit;
      double magic_number;
      datetime expiration_date;
      string comment;
      TradeType trade_type;
      TradeOperation trade_operation;
      bool is_filled;
      TradeState trade_state;
      double last_price;
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Trade::Trade()
{
    ticket_number       = 0;
    symbol              = "";
    open_price          = 0.0;
    datetime zerotime   = 0;
    open_time           = __DATETIME__;
    close_price         = 0.0;
    close_time          = __DATETIME__;
    volume              = 0.0;
    stoploss            = 0.0;
    take_profit         = 0.0;
    commission           = 0.0;
    swap                = 0.0;
    profit              = 0.0;
    magic_number        = 0.0;
    expiration_date     = __DATETIME__;
    comment             = "";
    trade_type          = TT_INVALID;
    trade_operation     = TO_INVALID;
    is_filled           = false;
    trade_state         = TS_INVALID;
    last_price          = 0.0;

}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
Trade::Trade(
                int ticket_num,
                string symb,
                double oprice,
                datetime otime,
                double cprice,
                datetime ctime,
                double vol,
                double sloss,
                double tprofit,
                double comm,
                double swp,
                double prft,
                double magic_num,
                datetime exp_date,
                string cmmnt,
                TradeType ttype,  
                TradeOperation toperation,
                bool filled,
                TradeState tstate,
                double lastprice
            )
{
    ticket_number        = ticket_num;
    symbol               = symb;
    open_price           = oprice;
    open_time            = otime;
    close_price          = cprice;
    close_time           = ctime;
    volume               = vol;
    stoploss             = sloss;
    take_profit          = tprofit;
    commission           = comm;
    swap                 = swp;
    profit               = prft;
    magic_number         = magic_num;
    expiration_date      = exp_date;
    comment              = cmmnt;
    trade_type           = ttype; 
    trade_operation      = toperation;
    is_filled            = filled;
    trade_state          = tstate;
    last_price           = lastprice;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Trade::~Trade()
{
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Trade::AsString()
{
   string ttype = "";
   if(trade_type == TT_INVALID){ttype = "INVALID";}
   if(trade_type == TT_LSMS){ttype = "LSMS";}
   if(trade_type == TT_LEWT){ttype = "LEWT";}
   if(trade_type == TT_SEWT){ttype = "SEWT";}
   if(trade_type == TT_SSMS){ttype = "SSMS";}
   
   string tstate = "";
   if(trade_state == TS_INVALID){tstate = "INVALID";}
   if(trade_state == TS_PENDING){tstate = "PENDING";}
   if(trade_state == TS_OPEN){tstate = "OPEN";}
   if(trade_state == TS_CLOSED){tstate = "CLOSED";}
   if(trade_state == TS_DELETED){tstate = "DELETED";}

   string toperation = "";
   if(trade_operation == TO_INVALID){toperation = "TO_INVALID";}
   if(trade_operation == TO_BUY){toperation = "TO_BUY";}
   if(trade_operation == TO_SELL){toperation = "TO_SELL";}
   if(trade_operation == TO_BUYLIMIT){toperation = "TO_BUYLIMIT";}
   if(trade_operation == TO_BUYSTOP){toperation = "TO_BUYSTOP";}
   if(trade_operation == TO_SELLLIMIT){toperation = "TO_SELLLIMIT";}
   if(trade_operation == TO_SELLSTOP){toperation = "TO_SELLSTOP";}

   string open_time_string = TimeToString(open_time,TIME_DATE|TIME_SECONDS);
   string close_time_string = TimeToString(close_time,TIME_DATE|TIME_SECONDS);
   string expiration_date_string = TimeToString(open_time,TIME_DATE|TIME_SECONDS);

   string str = StringFormat("%d,%s,%f,%s,%f,%s,%f,%f,%f,%f,%f,%f,%f,%s,%s,%s,%s,%s,%s,%f\n",
                            ticket_number,
                            symbol,
                            open_price,
                            open_time_string,
                            close_price,
                            close_time_string,
                            volume,
                            stoploss,
                            take_profit,
                            commission,
                            swap,
                            profit,
                            magic_number,
                            expiration_date_string,
                            comment,
                            ttype, 
                            toperation,
                            (is_filled ? "true":"false"),
                            tstate,
                            last_price
                  );
   return str;  
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Trade::Clear()
{
    ticket_number        = -1;
    symbol               = "";
    open_price           = 0.0;
    open_time            = __DATETIME__;
    close_price          = 0.0;
    close_time           = __DATETIME__;
    volume               = 0.0;
    stoploss             = 0.0;
    take_profit          = 0.0;
    commission           = 0.0;
    swap                 = 0.0;
    profit               = 0.0;
    magic_number         = 0.0;
    expiration_date      = __DATETIME__;
    comment              = "";
    trade_type           = TT_INVALID; 
    trade_operation      = TO_INVALID;
    is_filled            = false;
    trade_state          = TS_INVALID;
    last_price           = 0.0;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Trade::Copy(Trade &other)
{
    ticket_number        = other.ticket_number;
    symbol               = other.symbol;
    open_price           = other.open_price;
    open_time            = other.open_time;
    close_price          = other.close_price;
    close_time           = other.close_time;
    volume               = other.volume;
    stoploss             = other.stoploss;
    take_profit          = other.take_profit;
    commission           = other.commission;
    swap                 = other.swap;
    profit               = other.profit;
    magic_number         = other.magic_number;
    expiration_date      = other.expiration_date;
    comment              = other.comment;
    trade_type           = other.trade_type; 
    trade_operation      = other.trade_operation;
    is_filled            = other.is_filled;
    trade_state          = other.trade_state;
    last_price           = other.last_price;
}
//+------------------------------------------------------------------+
void Trade::SetTradeType(string str)
{
    if(str == "INVALID")
    {
        trade_type = TT_INVALID;
    }
    if(str == "LSMS")
    {
        trade_type = TT_LSMS;
    }
    if(str == "LEWT")
    {
        trade_type = TT_LEWT;
    }
    if(str == "SEWT")
    {
        trade_type = TT_SEWT;
    }
    if(str == "SSMS")
    {
        trade_type = TT_SSMS;
    }
}
//+------------------------------------------------------------------+
void Trade::SetTradeOperation(string str)
{
    if(str == "TO_INVALID")
    {
        trade_operation = TO_INVALID;
    }
    if(str == "TO_BUY")
    {
        trade_operation = TO_BUY;
    }
    if(str == "TO_SELL")
    {
        trade_operation = TO_SELL;
    }
    if(str == "TO_BUYLIMIT")
    {
        trade_operation = TO_BUYLIMIT;
    }
    if(str == "TO_BUYSTOP")
    {
        trade_operation = TO_BUYSTOP;
    }
    if(str == "TO_SELLLIMIT")
    {
        trade_operation = TO_SELLLIMIT;
    }
    if(str == "TO_SELLSTOP")
    {
        trade_operation = TO_SELLSTOP;
    }
}
//+------------------------------------------------------------------+
void Trade::SetTradeState(string str)
{
    if(str == "INVALID")
    {
        trade_state = TS_INVALID;
    }
    if(str == "PENDING")
    {
        trade_state = TS_PENDING;
    }
    if(str == "OPEN")
    {
        trade_state = TS_OPEN;
    }
    if(str == "CLOSED")
    {
        trade_state = TS_CLOSED;
    }
    if(str == "DELETED")
    {
        trade_state = TS_DELETED;
    }
}
void Trade::SetIsFilled(string str)
{
    if(str == "true")
    {
        is_filled = true;
    }
    if(str == "false")
    {
        is_filled = false;
    }
}