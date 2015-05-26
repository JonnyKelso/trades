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
    INVALID = 0x0,
    LSMS    = 0x1,
    LEWT    = 0x2,
    SEWT    = 0x4,
    SSMS    = 0x8
};

class Trade
{
private:

public:
       Trade();
       Trade(int ticket_num, string symb, double symb_price, double vol, double sloss, double tprofit, string cmmnt, TradeType tType);
      ~Trade();
      string AsString();
      void Clear();
      int ticket_number;
      string symbol;
      double price;
      double volume;
      double stoploss;
      double take_profit;
      string comment;
      TradeType trade_type;
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Trade::Trade()
  {
   ticket_number = 0;
   symbol = "";
   price = 0.0;
   volume = 0.0;
   stoploss = 0.0;
   take_profit = 0.0;
   comment = "";
   trade_type = 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
Trade::Trade(int ticket_num, string symb, double symb_price, double vol, double sloss, double tprofit, string cmmnt, TradeType tType)
{
   ticket_number = ticket_num;
   symbol = symb;
   price = symb_price;
   volume = vol;
   stoploss = sloss;
   take_profit = tprofit;
   comment = cmmnt;
   trade_type = tType;
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
   if(trade_type == LSMS){ttype = "LSMS";}
   if(trade_type == LEWT){ttype = "LEWT";}
   if(trade_type == SEWT){ttype = "SEWT";}
   if(trade_type == SSMS){ttype = "SSMS";}
   
   string str = StringFormat("%d,%s,%f,%f,%f,%f,%s,%s\n",
                  ticket_number,
                  symbol,
                  price,
                  volume,
                  stoploss,
                  take_profit,
                  comment,
                  ttype);
   return str;   
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Trade::Clear()
{
   ticket_number = 0;
   symbol = "";
   price = 0;
   volume = 0;
   stoploss = 0;
   take_profit = 0;
   comment = "";
   trade_type = INVALID; 

}
//+------------------------------------------------------------------+
