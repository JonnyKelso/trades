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
    TS_CLOSED
};
enum TradeOperation
{
    OP_INVALID,
    OP_BUY,          // - buy order,
    OP_SELL,         // - sell order,
    OP_BUYLIMIT,     // - buy limit pending order,
    OP_BUYSTOP,      // - buy stop pending order,
    OP_SELLLIMIT,    // - sell limit pending order,
    OP_SELLSTOP      // - sell stop pending order.
};

class Trade
{
private:

public:
       Trade();
       Trade(  int ticket_num;
               string symb;
               double oprice;
               datetime otime;
               double cprice;
               datetime ctime;
               double vol;
               double sloss;
               double tprofit;
               double comm;
               double swp;
               double prft;
               double magic_num;
               datetime exp_date;
               string cmmnt;
               TradeType ttype;  
               TradeOperation toperation;
               bool filled;
               TradeState tstate;
            );

      ~Trade();

      string AsString();
      void Clear();
      void Copy(Trade &other);
      
      int ticket_number;
      string symbol;
      double open_price;
      datetime open_time;
      double close_price;
      datetime close_time;
      double volume;
      double stoploss;
      double take_profit;
      double commision;
      double swap;
      double profit;
      double magic_number;
      datetime expiration_date;
      string comment;
      TradeType trade_type;
      TradeOperation trade_operation;
      bool is_filled;
      TradeState trade_state;
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
    commision           = 0.0;
    swap                = 0.0;
    profit              = 0.0;
    magic_number        = 0.0;
    expiration_date     = __DATETIME__;
    comment             = "";
    trade_type          = TT_INVALID;
    trade_operation     = OP_INVALID;
    is_filled           = false;
    trade_state         = TS_INVALID;

}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
Trade::Trade(
                int ticket_num;
                string symb;
                double oprice;
                datetime otime;
                double cprice;
                datetime ctime;
                double vol;
                double sloss;
                double tprofit;
                double comm;
                double swp;
                double prft;
                double magic_num;
                datetime exp_date;
                string cmmnt;
                TradeType ttype;  
                TradeOperation toperation;
                bool filled;
                TradeState tstate;
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

   string toperation = "";
   if(trade_operation == OP_INVALID){toperation = "INVALID";}
   if(trade_operation == OP_BUY){toperation = "OP_BUY";}
   if(trade_operation == OP_SELL){toperation = "OP_SELL";}
   if(trade_operation == OP_BUYLIMIT){toperation = "OP_BUYLIMIT";
   if(trade_operation == OP_BUYSTOP){toperation = "OP_BUYSTOP";
   if(trade_operation == OP_SELLLIMIT){toperation = "OP_SELLLIMIT";
   if(trade_operation == OP_SELLSTOP){toperation = "OP_SELLSTOP";

   string open_time_string = TimeToString(open_time,TIME_DATE|TIME_SECS);
   string close_time_string = TimeToString(close_time,TIME_DATE|TIME_SECS);
   string expiration_date_string = TimeToString(open_time,TIME_DATE|TIME_SECS);

   string str = StringFormat("%d,%s,%f,%s,%f,%s,%f,%f,%f,%f,%f,%f,%f,%s,%s,%d,%s\n",
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
                            tstate
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
    trade_operation      = OP_INVALID;
    is_filled            = false;
    trade_state          = TS_INVALID;
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
}
//+------------------------------------------------------------------+
