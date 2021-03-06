//+------------------------------------------------------------------+
//|                                              TradeControl_en.mq5 |
//|                                             Copyright KlimMalgin |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "zephyrrr"
#property link      ""
#property version   "1.00"

#include <Files\FileTxt.mqh>
#include <errordescription.mqh>

//#include <CNamedPipes.mqh>

datetime start_date = 0;   // Date, from which we begin to read history

int OrdersPrev = 0;        // Number of orders at the time of previous OnTrade() call
int PositionsPrev = 0;     // Number of positions at the time of previous OnTrade() call
int OrderCount;
int PositionCount;

/*
 *
 * Structure that stores information about positions
 *
 */
struct _position
{

long     type,          // Position type
         magic;         // Magic number for position
datetime time;          // Time of position opening

double   volume,        // Position volume
         priceopen,     // Position price
         sl,            // Stop Loss level for opened position
         tp,            // Take Profit level for opened position
         pricecurrent,  // Symbol current price
         comission,     // Commission
         swap,          // Accumulated swap
         profit;        // Current profit

string   symbol,        // Symbol, by which the position has been opened
         comment;       // Comment to position
};

_position PositionList[],  // Array that stores info about position
      PrevPositionList[];


/*
 *
 * Structure that stores information about orders
 *
 */
struct _orders
{

datetime time_setup,       // Time of order placement
         time_expiration,  // Time of order expiration
         time_done;        // Time of order execution or cancellation
         
long     type,             // Order type
         state,            // Order state
         type_filling,     // Type of execution by remainder
         type_time,        // Order lifetime
         ticket;           // Order ticket
         
long     magic,            // Id of Expert Advisor, that placed an order 
                           // (intended to ensure that each Expert 
                           // must place it's own unique number)
                           
         position_id;      // Position id, that is placed on order, 
                           // when it is executed. Each executed order invokes a 
                           // deal, that opens new or changes existing 
                           // position. Id of that position is placed on 
                           // executed order in this moment.
                           
double volume_initial,     // Initial volume on order placement
       volume_current,     // Unfilled volume
       price_open,         // Price, specified in the order
       sl,                 // Stop Loss level
       tp,                 // Take Profit level
       price_current,      // Current price by order symbol
       price_stoplimit;    // Price of placing Limit order when StopLimit order is triggered
       
string symbol,             // Symbol, by which the order has been placed
       comment;            // Comment
                           
};


_orders OrderList[],       // Arrays that store info about orders
        PrevOrderList[];

void SaveOrders()
{
    //OrdersPrev = OrdersTotal();
    GetOrders(PrevOrderList);
}

void SavePositions()
{
    PositionsPrev = PositionsTotal();
    GetPosition(PrevPositionList);
}

void PrintError(string msg)
{
    int error=GetLastError();
    Print(msg + " Error #", ErrorDescription(error));
    ResetLastError();
}
void PrintDebug(string msg)
{
    Print(msg);
}

//bool m_pipeInit = false;
//CNamedPipe m_namedPipe;
CFileTxt m_tradeFile;
void ShowTrade(string msg)
{
    Print(msg);
    
    while (m_tradeFile.Open(AccountInfoString(ACCOUNT_NAME) + "_trade.log", FILE_COMMON | FILE_READ | FILE_WRITE) == INVALID_HANDLE)
    {
    }
    m_tradeFile.Seek(0, SEEK_END);
    m_tradeFile.WriteString(TimeToString(TimeCurrent()));
    m_tradeFile.WriteString("\t");
    m_tradeFile.WriteString(msg);
    m_tradeFile.WriteString("\n");
    m_tradeFile.Close();
    
    //if (!m_pipeInit)
    //{
    //    if(m_namedPipe.Create())
    //    {
    //        if (m_namedPipe.Connect())
    //        {
    //            int tickReceived = m_namedPipe.WriteANSI("");
    //            if(GetError()==ERROR_BROKEN_PIPE)
    //            {
    //                m_namedPipe.Disconnect();
    //            }
    //        }
    //    }
    //    m_pipeInit = true;
    //}
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    start_date = 0;

    SavePositions();
    SaveOrders();
    
    m_tradeFile.SetCommon(true);
        
    m_tradeFile.Delete(AccountInfoString(ACCOUNT_NAME) + "_trade.log");
    
    return(0);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
//+------------------------------------------------------------------+
//| OnTrade function                                                 |
//+------------------------------------------------------------------+
void OnTrade()
{
    //PrintDebug("The Trade event occurred!");

    GetPosition(PositionList);
    GetOrders(OrderList);
    datetime dc = TimeCurrent();
    HistorySelect(start_date,dc);

    // 有Order增加
    if (OrdersPrev < OrdersTotal())
    {
        //ulong lastOrderTicket = OrderGetTicket(OrdersTotal()-1);  // Select the last order to work with
        ulong lastOrderTicket = OrderGetTicket(OrdersPrev);
        if (lastOrderTicket == 0)
        {
            PrintError("Retrieve Last Order error!");
            return;
        }
        OrderSelect(lastOrderTicket);
        long state = OrderGetInteger(ORDER_STATE);
        if (state == ORDER_STATE_STARTED)
        {
            //PrintDebug(IntegerToString(lastOrderTicket) + " Order has arrived for processing!");
            string orderType = NULL;
            switch(OrderGetInteger(ORDER_TYPE))
            {
                case ORDER_TYPE_BUY:
                    orderType = "ORDER_TYPE_BUY";
                    break;
                case ORDER_TYPE_SELL:
                    orderType = "ORDER_TYPE_SELL";
                    break;
                default:
                    PrintError("wrong order type of ORDER_TYPE_BUY or ORDER_TYPE_SELL!");
                    break;
             }
             if (orderType != NULL)
                {
                    ShowTrade("OrderOpen(" 
                        + IntegerToString(OrderGetInteger(ORDER_MAGIC)) + ", "
                        + OrderGetString(ORDER_SYMBOL) + ","
                            + orderType + ", " 
                            + DoubleToString(OrderGetDouble(ORDER_VOLUME_CURRENT), 5) + ", "
                            + DoubleToString(OrderGetDouble(ORDER_PRICE_STOPLIMIT), 5) + ", "
                            + DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN), 5) + ", "
                            + DoubleToString(OrderGetDouble(ORDER_SL), 5) + ", "
                            + DoubleToString(OrderGetDouble(ORDER_TP), 5)+ ", "
                            + IntegerToString(OrderGetInteger(ORDER_TYPE_TIME)) + ","
                            + IntegerToString(OrderGetInteger(ORDER_TIME_EXPIRATION)) + ","
                            + OrderGetString(ORDER_COMMENT) + ")");
                    OrdersPrev++;
                }
        }
        else if (state == ORDER_STATE_PLACED)
        {
            string orderType = NULL;
            switch(OrderGetInteger(ORDER_TYPE))
            {
                case ORDER_TYPE_BUY:
                case ORDER_TYPE_SELL:
                    PrintError("wrong order type of ORDER_TYPE_BUY or ORDER_TYPE_SELL!");
                    break;
                case ORDER_TYPE_BUY_LIMIT:
                    orderType = "ORDER_TYPE_BUY_LIMIT";
                    break;
                case ORDER_TYPE_SELL_LIMIT:
                    orderType = "ORDER_TYPE_SELL_LIMIT";
                    break;
         
                case ORDER_TYPE_BUY_STOP:
                    orderType = "ORDER_TYPE_BUY_STOP";
                    break;
         
                case ORDER_TYPE_SELL_STOP:
                    orderType = "ORDER_TYPE_SELL_STOP";
                    break;
         
                case ORDER_TYPE_BUY_STOP_LIMIT:
                    orderType = "ORDER_TYPE_BUY_STOP_LIMIT";
                    break;
                 
                case ORDER_TYPE_SELL_STOP_LIMIT:
                    orderType = "ORDER_TYPE_SELL_STOP_LIMIT";
                    break;    
                default:
                    PrintError("unprocessed Order type of " + IntegerToString(OrderGetInteger(ORDER_TYPE)));
                    break;
            }
            if (orderType != NULL)
            {
                ShowTrade("OrderOpen(" 
                    + IntegerToString(OrderGetInteger(ORDER_MAGIC)) + ", "
                    + OrderGetString(ORDER_SYMBOL) + ","
                        + orderType + ", " 
                        + DoubleToString(OrderGetDouble(ORDER_VOLUME_CURRENT), 5) + ", "
                        + DoubleToString(OrderGetDouble(ORDER_PRICE_STOPLIMIT), 5) + ", "
                        + DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN), 5) + ", "
                        + DoubleToString(OrderGetDouble(ORDER_SL), 5) + ", "
                        + DoubleToString(OrderGetDouble(ORDER_TP), 5)+ ", "
                        + IntegerToString(OrderGetInteger(ORDER_TYPE_TIME)) + ","
                        + IntegerToString(OrderGetInteger(ORDER_TIME_EXPIRATION)) + ","
                        + OrderGetString(ORDER_COMMENT) + ")");
                OrdersPrev++;
            }
        }
        else
        {
            PrintError("unprocessed Order state of " + IntegerToString(state) + " when new order!");
        }
    }
    // 有Order减少， 到History中去了
    else if(OrdersPrev > OrdersTotal())
    {
        long lastOrderTicket = HistoryOrderGetTicket(HistoryOrdersTotal()-1);
        if (lastOrderTicket == 0)
        {
            PrintError("Last Order is 0!");
        }
        HistoryOrderSelect(lastOrderTicket);
        
        long state = 0;
        if (!HistoryOrderGetInteger(lastOrderTicket, ORDER_STATE, state))
        {
            PrintError("Can't get the state of last orderticker of " + IntegerToString(lastOrderTicket));
        }

        if (state == ORDER_STATE_CANCELED)
        {
            ShowTrade("OrderDelete(" + IntegerToString(HistoryOrderGetInteger(lastOrderTicket, ORDER_MAGIC)) + "," 
                + IntegerToString(lastOrderTicket) + ")");
            OrdersPrev--;
        }
        else if (state == ORDER_STATE_FILLED)
        {
            // Do nothing, generate in ORDER_STATE_STARTED
            OrdersPrev--;
        }
        else
        {
            PrintError("Unprocessed Order state of " + IntegerToString(state) + " when order release");
        }
    } 
//    else if (PositionsPrev < PositionsTotal() || PositionsPrev > PositionsTotal())
//    {
//        long lastDealTicket = HistoryDealGetTicket(HistoryDealsTotal()-1);
//        PositionSelect(HistoryDealGetString(lastDealTicket, DEAL_SYMBOL));
//        
//        switch(HistoryDealGetInteger(lastDealTicket, DEAL_TYPE))
//        {
//            case DEAL_TYPE_BUY:
//                ShowTrade("PositionOpen(" + HistoryDealGetString(lastDealTicket, DEAL_SYMBOL) 
//                                    + ", ORDER_TYPE_BUY, " 
//                                    + DoubleToString(HistoryDealGetDouble(lastDealTicket, DEAL_VOLUME), 5) + ", "
//                                    + DoubleToString(HistoryDealGetDouble(lastDealTicket, DEAL_PRICE), 5) + ", "
//                                    + DoubleToString(PositionGetDouble(POSITION_SL), 5) + ", "
//                                    + DoubleToString(PositionGetDouble(POSITION_TP), 5)+ ", "
//                                    + OrderGetString(ORDER_COMMENT) + ")");
//                break;
//            case DEAL_TYPE_SELL:
//                ShowTrade("PositionOpen(" + HistoryDealGetString(lastDealTicket, DEAL_SYMBOL) 
//                                    + ", ORDER_TYPE_SELL, " 
//                                    + DoubleToString(HistoryDealGetDouble(lastDealTicket, DEAL_VOLUME), 5) + ", "
//                                    + DoubleToString(HistoryDealGetDouble(lastDealTicket, DEAL_PRICE), 5) + ", "
//                                    + DoubleToString(PositionGetDouble(POSITION_SL), 5) + ", "
//                                    + DoubleToString(PositionGetDouble(POSITION_TP), 5)+ ", "
//                                    + OrderGetString(ORDER_COMMENT) + ")");
//                break;
//            default:
//                PrintError("Unprocessed deal type of " + IntegerToString(HistoryDealGetInteger(lastDealTicket, DEAL_TYPE)));
//        }
//    }
    else if (OrdersPrev == OrdersTotal())
    {
        for (int i = 0;i<OrderCount;i++)
        {
            if (PrevOrderList[i].price_open != OrderList[i].price_open
                || PrevOrderList[i].sl != OrderList[i].sl || PrevOrderList[i].tp != OrderList[i].tp)
            {
                ShowTrade("OrderModify(" +
                    IntegerToString(i) + ", " + 
                    IntegerToString(OrderList[i].ticket) + ", " + 
                    DoubleToString(OrderList[i].price_open, 5) + ", " + 
                    DoubleToString(OrderList[i].sl, 5) + ", " + 
                    DoubleToString(OrderList[i].tp, 5) + ", " + 
                    IntegerToString(OrderList[i].type_time) + ", " + 
                    IntegerToString(OrderList[i].time_expiration) + ")");
                //_alerts += "Order "+OrderList[i].ticket+" has changed Stop Loss from "+ PrevOrderList[i].sl +" to "+ OrderList[i].sl +"\n";
            }
        }
    }
    else
    {
        PrintError("Unprocessed condition!" + "OrdersPrev = " + IntegerToString(OrdersPrev) + ", OrderTotal = "
            + IntegerToString(OrdersTotal()) + ", PositionPrev = " + IntegerToString(PositionsPrev)
            + ", PositionsTotal = " + IntegerToString(PositionsTotal()));
    }
    SaveOrders();
    
    if (PositionsPrev == PositionsTotal())
    {
        for (int i=0;i<PositionCount;i++)
        {
            if (PrevPositionList[i].sl != PositionList[i].sl || PrevPositionList[i].tp != PositionList[i].tp)
            {
                ShowTrade("PositionModify(" + 
                    PositionList[i].symbol + ", " + 
                    DoubleToString(PositionList[i].sl, 5) + ", " + 
                    DoubleToString(PositionList[i].tp, 5) + ")");
                //_alerts += "On pair "+PositionList[i].symbol+" Stop Loss changed from "+ PrevPositionList[i].sl +" to "+ PositionList[i].sl +"\n";
            }
        }
    }
    
    SavePositions();
    
    //PrintDebug("OrdersPrev = " + IntegerToString(OrdersPrev) + ", OrderTotal = "
    //        + IntegerToString(OrdersTotal()) + ", PositionPrev = " + IntegerToString(PositionsPrev)
    //        + ", PositionsTotal = " + IntegerToString(PositionsTotal()));
}


void GetPosition(_position &Array[])
{
    int _PositionsTotal=PositionsTotal();

    int temp_value=(int)MathMax(_PositionsTotal,1);
    ArrayResize(Array, temp_value);

    PositionCount=0;
    for(int z=_PositionsTotal-1; z>=0; z--)
    {
        if(!PositionSelect(PositionGetSymbol(z)))
        {
            PrintError("OrderSelect() - Error #");
            continue;
        }
        else
        {
            // If the position is found, then put its info to the array
            Array[z].type         = PositionGetInteger(POSITION_TYPE);
            Array[z].time         = PositionGetInteger(POSITION_TIME);
            Array[z].magic        = PositionGetInteger(POSITION_MAGIC);
            Array[z].volume       = PositionGetDouble(POSITION_VOLUME);
            Array[z].priceopen    = PositionGetDouble(POSITION_PRICE_OPEN);
            Array[z].sl           = PositionGetDouble(POSITION_SL);
            Array[z].tp           = PositionGetDouble(POSITION_TP);
            Array[z].pricecurrent = PositionGetDouble(POSITION_PRICE_CURRENT);
            Array[z].comission    = PositionGetDouble(POSITION_COMMISSION);
            Array[z].swap         = PositionGetDouble(POSITION_SWAP);
            Array[z].profit       = PositionGetDouble(POSITION_PROFIT);
            Array[z].symbol       = PositionGetString(POSITION_SYMBOL);
            Array[z].comment      = PositionGetString(POSITION_COMMENT);
            PositionCount++;
        }
     }

    temp_value=(int)MathMax(PositionCount,1);
    ArrayResize(Array,temp_value);
}


//+------------------------------------------------------------------+
//| Function GetOrders()                                             |
//+------------------------------------------------------------------+
void GetOrders(_orders &OrdersList[])
{
    int _OrdersTotal=OrdersTotal();

    int temp_value=(int)MathMax(_OrdersTotal,1);
    ArrayResize(OrdersList,temp_value);

    OrderCount=0;
    for(int z=_OrdersTotal-1; z>=0; z--)
    {
        if(!OrderGetTicket(z))
        {
            PrintError("GetOrders() - Error #");
            continue;
        }
        else
        {
            OrdersList[z].ticket          = OrderGetTicket(z);
            OrdersList[z].time_setup      = OrderGetInteger(ORDER_TIME_SETUP);
            OrdersList[z].time_expiration = OrderGetInteger(ORDER_TIME_EXPIRATION);
            OrdersList[z].time_done       = OrderGetInteger(ORDER_TIME_DONE);
            OrdersList[z].type            = OrderGetInteger(ORDER_TYPE);
            
            OrdersList[z].state           = OrderGetInteger(ORDER_STATE);
            OrdersList[z].type_filling    = OrderGetInteger(ORDER_TYPE_FILLING);
            OrdersList[z].type_time       = OrderGetInteger(ORDER_TYPE_TIME);
            OrdersList[z].magic           = OrderGetInteger(ORDER_MAGIC);
            OrdersList[z].position_id     = OrderGetInteger(ORDER_POSITION_ID);
            
            OrdersList[z].volume_initial  = OrderGetDouble(ORDER_VOLUME_INITIAL);
            OrdersList[z].volume_current  = OrderGetDouble(ORDER_VOLUME_CURRENT);
            OrdersList[z].price_open      = OrderGetDouble(ORDER_PRICE_OPEN);
            OrdersList[z].sl              = OrderGetDouble(ORDER_SL);
            OrdersList[z].tp              = OrderGetDouble(ORDER_TP);
            OrdersList[z].price_current   = OrderGetDouble(ORDER_PRICE_CURRENT);
            OrdersList[z].price_stoplimit = OrderGetDouble(ORDER_PRICE_STOPLIMIT);
            
            OrdersList[z].symbol          = OrderGetString(ORDER_SYMBOL);
            OrdersList[z].comment         = OrderGetString(ORDER_COMMENT);
            
            OrderCount++;
        }
    }

    temp_value=(int)MathMax(OrderCount,1);
    ArrayResize(OrdersList,temp_value);
}