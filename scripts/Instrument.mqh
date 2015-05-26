//+------------------------------------------------------------------+
//|                                                   Instrument.mqh |
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
class Instrument
 {
private:
   
public:
       Instrument();
       Instrument(string symb, string base, double min_tsize, double lsize, double pip_loc, int lsms, int lewt, int sewt, int ssms);
      ~Instrument();
      string AsString();
      void Clear();
                    
      string symbol;
      string base_currency_chart;
      double min_trade_size;
      double lot_size;
      double pip_location;
      int lsms_trade;
      int lewt_trade;
      int sewt_trade;
      int ssms_trade;
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Instrument::Instrument()
{
      symbol = "";
      base_currency_chart = "";
      min_trade_size = 0;
      lot_size = 0;
      pip_location = 0;
      lsms_trade = 0;
      lewt_trade = 0;
      sewt_trade = 0;
      ssms_trade = 0;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Instrument::Instrument(string symb, string base, double min_tsize, double lsize, double pip_loc, int lsms, int lewt, int sewt, int ssms)
{
      symbol = symb;
      base_currency_chart = base;
      min_trade_size = min_tsize;
      lot_size = lsize;
      pip_location = pip_loc;
      lsms_trade = lsms;
      lewt_trade = lewt;
      sewt_trade = sewt;
      ssms_trade = ssms;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Instrument::~Instrument()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Instrument::AsString()
{
   string str = StringFormat("%s,%s,%f,%f,%f,%d,%d,%d,%d,\n",
                  symbol,
                  base_currency_chart,
                  min_trade_size,
                  lot_size,
                  pip_location,
                  lsms_trade,
                  lewt_trade,
                  sewt_trade,
                  ssms_trade);
   return str;   
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Instrument::Clear()
{
   symbol = "";
   base_currency_chart = "";
   min_trade_size = 0;
   lot_size = 0;
   pip_location = 0;
   lsms_trade = 0;
   lewt_trade = 0;
   sewt_trade = 0;
   ssms_trade = 0;
}
//+------------------------------------------------------------------+