-- phpMyAdmin SQL Dump
-- version 4.7.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Aug 06, 2018 at 08:30 PM
-- Server version: 10.2.7-MariaDB
-- PHP Version: 5.5.38

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `S18336Pteam7`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`S18336Pteam7`@`localhost` PROCEDURE `HFT_SLOPE` (IN `Loops` INT(5))  BEGIN
declare this_instrument int(11);
declare this_quote_date date;
declare this_quote_seq_nbr int(11);
declare this_trading_symbol varchar(15);
declare this_quote_time datetime;
declare this_ask_price decimal(18,4);
declare this_ask_size int(11);
declare this_bid_price decimal(18,4);
declare this_bid_size int(11);
declare loopcount int(11);
declare maxloops int(11);
declare future_bid_price decimal(18,4);
declare future_ask_price decimal(18,4);
/*varaible for SLOPE table*/
declare qa_last_ask_price decimal(18,4);
declare qa_last_bid_price decimal(18,4);
declare qa_bid_slope decimal(18,4);
declare qa_ask_slope decimal(18,4);
declare qa_datetime_ask datetime;
declare qa_datetime_bid datetime;
declare extra_quote int(11);
declare db_done int default false;
declare s_difference int(11);
declare cur1 cursor for select * from STOCK_QUOTE_FEED use index for order by (XK2_STOCK_QUOTE,XK4_STOCK_QUOTE)  order by QUOTE_SEQ_NBR,QUOTE_TIME;
declare continue handler for not found set db_done=1;
set maxloops=loops;
set loopcount=0;
set extra_quote = 0;
open cur1;
   quote_loop: LOOP
        if (db_done OR loopcount=maxloops) then leave quote_loop; end if;
        /* copy record */
        fetch cur1 into this_instrument, this_quote_date, this_quote_seq_nbr, this_trading_symbol, this_quote_time, this_ask_price, this_ask_size, this_bid_price, this_bid_size;
        /* write out the record*/
       IF NOT EXISTS( SELECT 1 FROM STOCK_SLOPE WHERE TRADING_SYMBOL = this_trading_symbol) then
       /* write difference quote time based on bid or ask*/
       if this_bid_price > 0 then
       insert into STOCK_SLOPE(INSTRUMENT_ID, ASK_PRICE, BID_PRICE, TRADING_SYMBOL,SLOPE_BID,SLOPE_ASK,QUOTE_TIME_BID) values(this_instrument,this_ask_price, this_bid_price,this_trading_symbol,1.0,1.0,this_quote_time);
       else
       /* ask */
       insert into STOCK_SLOPE(INSTRUMENT_ID, ASK_PRICE, BID_PRICE, TRADING_SYMBOL,SLOPE_BID,SLOPE_ASK,QUOTE_TIME_ASK) values(this_instrument,this_ask_price, this_bid_price,this_trading_symbol,1.0,1.0,this_quote_time);
       end if;
        /*if it is not the first record*/
       else
       /*get the record*/
          select ASK_PRICE,BID_PRICE, SLOPE_BID,SLOPE_ASK,QUOTE_TIME_ASK, QUOTE_TIME_BID into qa_last_ask_price,qa_last_bid_price, qa_bid_slope, qa_ask_slope,qa_datetime_ask, qa_datetime_bid from STOCK_SLOPE where TRADING_SYMBOL = this_trading_symbol;
       if this_ask_price > 0 THEN
       /* calculate the difference of time */
       set s_difference = TIMESTAMPDIFF(second,qa_datetime_ask,this_quote_time);
       /* it is ask, update the last ask price and slope*/
       	update STOCK_SLOPE set ASK_PRICE = this_ask_price where TRADING_SYMBOL = this_trading_symbol;
        /* the slope is the difference of price divide difference of datetime */
        set qa_ask_slope = (this_ask_price - qa_last_ask_price)/s_difference;
        /* update time and slope */
        update STOCK_SLOPE set SLOPE_ASK = qa_ask_slope where TRADING_SYMBOL = this_trading_symbol;
        update STOCK_SLOPE set QUOTE_TIME_ASK = this_quote_time WHERE
        TRADING_SYMBOL = this_trading_symbol;
        end if;
        /* same here */
       if this_bid_price > 0 then
       	  /* it is bid */
          /* caculate the difference of time in Second */
          set s_difference = TIMESTAMPDIFF(second,qa_datetime_bid,this_quote_time);
          /* update the price */
            update STOCK_SLOPE set BID_PRICE = this_bid_price where TRADING_SYMBOL = this_trading_symbol;
            /* find the slope by difference of price divine by difference of dateim */
            set qa_bid_slope = (this_bid_price - qa_last_bid_price)/s_difference;
            /* update slope and datetime */
            update STOCK_SLOPE set SLOPE_BID = qa_bid_slope where TRADING_SYMBOL = this_trading_symbol;
                    update STOCK_SLOPE set QUOTE_TIME_BID = this_quote_time WHERE
        TRADING_SYMBOL = this_trading_symbol;
       	end if;
       end if;
          /*to get a match point, the direction of bid and ask cannot be the same*/
          /* this condition is when bid is increased and ask is decreased*/
      if (qa_bid_slope > 0 and qa_ask_slope < 0) then
            /*when we find a predicted intersection point*/
            set future_ask_price = this_ask_price + (this_ask_price *qa_ask_slope);
            set future_bid_price = this_bid_price + (this_bid_price * qa_bid_slope);
       if future_ask_price = future_bid_price then
              /*we need to add one quote for buy ask price */
              set extra_quote = extra_quote + 1;
              set this_quote_time = DATEADD(s,1,this_quote_time);
                            /* insert the bid quote, we need to swtich the position of bid and ask, since we need to buy the same same of price and size
              NOTES: this is for real case, since assume we have nothing, we need to buy first then sell. but we still can assume we have the stock
              therefore we only need to sell them with intersection price.
              extra_quote = extra_quote + 1;
              */
              insert into STOCK_QUOTE_FEED2 values(this_instrument + extra_quote, this_quote_date, this_quote_seq_nbr + extra_quote, this_trading_symbol, this_quote_time, this_bid_price, this_bid_size, this_ask_price, this_ask_size);
              /*sell them with future price*/
              set extra_quote = extra_quote + 1;
              set this_quote_time = DATEADD(s,1,this_quote_time);
           insert into STOCK_QUOTE_FEED2 values(this_instrument + extra_quote, this_quote_date, this_quote_seq_nbr + extra_quote, this_trading_symbol, this_quote_time, future_ask_price, this_ask_size, this_bid_price, this_bid_size);
       end if;
      end if;
        set loopcount=loopcount+1;
        END LOOP;
close cur1;
END$$

CREATE DEFINER=`S18336Pteam7`@`localhost` PROCEDURE `matchask` (IN `c_id` INT, IN `c_quote_date` DATE, IN `c_seq_nbr` INT, IN `c_symbol` VARCHAR(15), IN `c_time` DATETIME, IN `c_ask_price` DECIMAL, IN `c_ask_size` INT, IN `c_bid_price` DECIMAL, IN `c_bid_size` INT)  BEGIN
declare s_id int(11);
declare s_quote_date date;
declare s_seq_nbr int(11);
declare s_ask_price decimal(18,4);
declare s_ask_size int(11);
declare s_bid_price decimal(18,4);
declare s_bid_size int(11);
declare db_done int default false;

DECLARE cur CURSOR FOR
SELECT INSTRUMENT_ID, QUOTE_DATE, QUOTE_SEQ_NBR, BID_PRICE, BID_SIZE
FROM STOCK_QUOTE_FEED2
WHERE INSTRUMENT_ID = c_id and BID_PRICE >= c_ask_price
ORDER BY QUOTE_SEQ_NBR;

declare continue handler for not found set db_done=1;

if c_ask_price > 0 then
  OPEN cur;
  ask_loop: LOOP
  FETCH cur INTO s_id, s_quote_date, s_seq_nbr, s_bid_price, s_bid_size;
  if (db_done OR c_ask_size <= 0) then leave ask_loop; end if;

  if s_bid_size <= c_ask_size then
    INSERT INTO STOCK_TRADE VALUES(c_id, c_quote_date, s_seq_nbr, c_symbol, c_time, c_ask_price, s_bid_size);
    DELETE FROM STOCK_QUOTE_FEED2
    WHERE INSTRUMENT_ID = s_id and QUOTE_SEQ_NBR = s_seq_nbr and QUOTE_DATE = s_quote_date;
    DELETE FROM STOCK_QUOTE_FEED2 
    WHERE INSTRUMENT_ID = c_id and QUOTE_SEQ_NBR = c_seq_nbr and QUOTE_DATE = c_quote_date;
    UPDATE STOCK_QUOTE_FEED2 SET ASK_SIZE = c_ask_size
    WHERE INSTRUMENT_ID = c_id and QUOTE_SEQ_NBR = c_seq_nbr and QUOTE_DATE = c_quote_date;

  else
    INSERT INTO STOCK_TRADE VALUES(c_id, c_quote_date, s_seq_nbr, c_symbol, c_time, c_ask_price, c_ask_size);
    DELETE FROM STOCK_QUOTE_FEED2
    WHERE INSTRUMENT_ID = c_id and QUOTE_SEQ_NBR = c_seq_nbr and QUOTE_DATE = c_quote_date;
    DELETE FROM STOCK_QUOTE_FEED2 
    WHERE INSTRUMENT_ID = s_id and QUOTE_SEQ_NBR = s_seq_nbr and QUOTE_DATE = s_quote_date;
    UPDATE STOCK_QUOTE_FEED2 SET BID_SIZE = s_bid_size - c_ask_size
    WHERE INSTRUMENT_ID = s_id and QUOTE_SEQ_NBR = s_seq_nbr and QUOTE_DATE = s_quote_date;
    SET c_ask_size = 0;

  end if;
  END LOOP;
  CLOSE cur;

end if;

END$$

CREATE DEFINER=`S18336Pteam7`@`localhost` PROCEDURE `matchbid` (IN `c_id` INT, IN `c_quote_date` DATE, IN `c_seq_nbr` INT, IN `c_symbol` VARCHAR(15), IN `c_time` DATETIME, IN `c_ask_price` DECIMAL, IN `c_ask_size` INT, IN `c_bid_price` DECIMAL, IN `c_bid_size` INT)  BEGIN
declare s_id int(11);
declare s_quote_date date;
declare s_seq_nbr int(11);
declare s_ask_price decimal(18,4);
declare s_ask_size int(11);
declare s_bid_price decimal(18,4);
declare s_bid_size int(11);
declare db_done int default false;

DECLARE cur CURSOR FOR
SELECT INSTRUMENT_ID, QUOTE_DATE, QUOTE_SEQ_NBR, ASK_PRICE, ASK_SIZE
FROM STOCK_QUOTE_FEED2
WHERE INSTRUMENT_ID = c_id and ASK_PRICE <= c_bid_price and ASK_PRICE > 0
ORDER BY QUOTE_SEQ_NBR;

declare continue handler for not found set db_done=1;

if c_bid_price > 0 then
  OPEN cur;
  bid_loop: LOOP
  FETCH cur INTO s_id, s_quote_date, s_seq_nbr, s_ask_price, s_ask_size;
  if (db_done OR c_bid_size <= 0) then leave bid_loop; end if;
  
  if s_ask_size <= c_bid_size then
    INSERT INTO STOCK_TRADE VALUES(c_id, c_quote_date, s_seq_nbr, c_symbol, c_time, s_ask_price, s_ask_size);
    DELETE FROM STOCK_QUOTE_FEED2
    WHERE INSTRUMENT_ID = s_id and QUOTE_SEQ_NBR = s_seq_nbr and QUOTE_DATE = s_quote_date;
    DELETE FROM STOCK_QUOTE_FEED2 
    WHERE INSTRUMENT_ID = c_id and QUOTE_SEQ_NBR = c_seq_nbr and QUOTE_DATE = c_quote_date;
    UPDATE STOCK_QUOTE_FEED2 SET BID_SIZE = c_bid_size
    WHERE INSTRUMENT_ID = c_id and QUOTE_SEQ_NBR = c_seq_nbr and QUOTE_DATE = c_quote_date;
    
  else
    INSERT INTO STOCK_TRADE VALUES(c_id, c_quote_date, s_seq_nbr, c_symbol, c_time, s_ask_price, c_bid_size);
    DELETE FROM STOCK_QUOTE_FEED2
    WHERE INSTRUMENT_ID = c_id and QUOTE_SEQ_NBR = c_seq_nbr and QUOTE_DATE = c_quote_date;
    DELETE FROM STOCK_QUOTE_FEED2 
    WHERE INSTRUMENT_ID = s_id and QUOTE_SEQ_NBR = s_seq_nbr and QUOTE_DATE = s_quote_date;
   UPDATE STOCK_QUOTE_FEED2 SET ASK_SIZE = s_ask_size - c_bid_size
    WHERE INSTRUMENT_ID = s_id and QUOTE_SEQ_NBR = s_seq_nbr and QUOTE_DATE = s_quote_date;
    SET c_bid_size = 0;
  end if;
  END LOOP;
  CLOSE cur;
  
  end if;

END$$

CREATE DEFINER=`S18336Pteam7`@`localhost` PROCEDURE `sp_quote_feed_randparms` (IN `loops` INT, IN `switch_seed` INT, IN `amp_seed` INT)  BEGIN
declare this_instrument int(11);
declare this_quote_date date;
declare this_quote_seq_nbr int(11);
declare this_trading_symbol varchar(15);
declare this_quote_time datetime;
declare this_ask_price decimal(18,4);
declare this_ask_size int(11);
declare this_bid_price decimal(18,4);
declare this_bid_size int(11);
declare loopcount int(11);
declare maxloops int(11);
/*variables for S18336Pteam7.QUOTE_ADJUST values*/
declare qa_last_ask_price decimal(18,4);
declare qa_last_ask_seq_nbr int(11);
declare qa_last_bid_price decimal(18,4);
declare qa_last_bid_seq_nbr int(11);
declare qa_amplitude decimal(18,4);
declare qa_switchpoint int(11);
declare qa_direction tinyint;
declare db_done int default false;
declare cur1 cursor for select * from stockmarket.STOCK_QUOTE use index for order by (XK2_STOCK_QUOTE,XK4_STOCK_QUOTE)  order by QUOTE_SEQ_NBR,QUOTE_TIME;
declare continue handler for not found set db_done=1;
set maxloops=loops;
set loopcount=1;
open cur1;
   quote_loop: LOOP
        if (db_done OR loopcount=maxloops) then leave quote_loop; end if;
        fetch cur1 into this_instrument, this_quote_date, this_quote_seq_nbr, this_trading_symbol, this_quote_time, this_ask_price, this_ask_size, this_bid_price, this_bid_size;
        /*all update logic goes here...first get stockmarket.QUOTE_ADJUST values into variables*/
        select LAST_ASK_PRICE,LAST_ASK_SEQ_NBR,LAST_BID_PRICE,LAST_BID_SEQ_NBR,AMPLITUDE,SWITCHPOINT, DIRECTION into qa_last_ask_price,qa_last_ask_seq_nbr,qa_last_bid_price,qa_last_bid_seq_nbr,qa_amplitude,qa_switchpoint,qa_direction from S18336Pteam7.QUOTE_ADJUST where INSTRUMENT_ID=this_instrument;
        if this_ask_price > 0 then /* it is an ask*/

                update S18336Pteam7.QUOTE_ADJUST set LAST_ASK_PRICE=this_ask_price where INSTRUMENT_ID=this_instrument;
                update S18336Pteam7.QUOTE_ADJUST set LAST_ASK_SEQ_NBR=this_quote_seq_nbr where INSTRUMENT_ID=this_instrument;
                if qa_last_ask_price > 0 then /*not first ask for this inst*/

                        set this_ask_price=qa_last_ask_price+(ABS(this_ask_price-qa_last_ask_price)*qa_amplitude*qa_direction);
                    end if;


        else /*it is a bid*/
                update S18336Pteam7.QUOTE_ADJUST set LAST_BID_PRICE=this_bid_price where INSTRUMENT_ID=this_instrument;
                update S18336Pteam7.QUOTE_ADJUST set LAST_BID_SEQ_NBR=this_quote_seq_nbr where INSTRUMENT_ID=this_instrument;
                if qa_last_bid_price > 0 then /*not first bid for this inst*/

                        set this_bid_price=qa_last_bid_price+(ABS(this_bid_price-qa_last_bid_price)*qa_amplitude*qa_direction);
                    end if;

        end if;  /* end if this is an ask or a bid*/
/* in all cases check and reset switchpoint if needed reset amplitude and update dates*/
        if qa_switchpoint > 0 then

                        update S18336Pteam7.QUOTE_ADJUST set SWITCHPOINT=SWITCHPOINT-1 where INSTRUMENT_ID=this_instrument ;
                    else  /*switchpoint <=0, recalculate switchpoint and change direction */
                        update S18336Pteam7.QUOTE_ADJUST set SWITCHPOINT=ROUND((RAND()+.5)*switch_seed), DIRECTION=DIRECTION*-1 where INSTRUMENT_ID=this_instrument;
                end if;
        update S18336Pteam7.QUOTE_ADJUST set AMPLITUDE=(RAND()+ amp_seed) where INSTRUMENT_ID=this_instrument;
        set this_quote_date=DATE_ADD(this_quote_date, INTERVAL 12 YEAR);
        set this_quote_time=DATE_ADD(this_quote_time, INTERVAL 12 YEAR);
/* now write out the record*/
        insert into S18336Pteam7.STOCK_QUOTE_FEED values(this_instrument, this_quote_date, this_quote_seq_nbr, this_trading_symbol, this_quote_time, this_ask_price, this_ask_size, this_bid_price, this_bid_size);
        set loopcount=loopcount+1;
        END LOOP;
close cur1;
END$$

CREATE DEFINER=`S18336Pteam7`@`localhost` PROCEDURE `sp_quote_test` (IN `loops` INT)  BEGIN
declare this_instrument int(11);
declare this_quote_date date;
declare this_quote_seq_nbr int(11);
declare this_trading_symbol varchar(15);
declare this_quote_time datetime;
declare this_ask_price decimal(18,4);
declare this_ask_size int(11);
declare this_bid_price decimal(18,4);
declare this_bid_size int(11);
declare loopcount int(11);
declare maxloops int(11);
/*variables for QUOTE_ADJUST values*/
declare qa_last_ask_price decimal(18,4);
declare qa_last_ask_seq_nbr int(11);
declare qa_last_bid_price decimal(18,4);
declare qa_last_bid_seq_nbr int(11);
declare qa_amplitude decimal(18,4);
declare qa_switchpoint int(11);
declare qa_direction tinyint;
declare db_done int default false;
declare cur1 cursor for
select * from stockmarket.STOCK_QUOTE  use index for order by (XK2_STOCK_QUOTE,XK4_STOCK_QUOTE) where TRADING_SYMBOL in ('AAA','ABB','ACC','ADD') order by QUOTE_SEQ_NBR,QUOTE_TIME;
declare continue handler for not found set db_done=1;
set maxloops=loops*1000;
set loopcount=1;
open cur1;
   quote_loop: LOOP
        if (db_done OR loopcount=maxloops) then leave quote_loop; end if;
        fetch cur1 into this_instrument, this_quote_date, this_quote_seq_nbr, this_trading_symbol, this_quote_time, this_ask_price, this_ask_size, this_bid_price, this_bid_size;
        /*all update logic goes here...first get S18336Pteam6.QUOTE_ADJUST values into variables*/
        select LAST_ASK_PRICE,LAST_ASK_SEQ_NBR,LAST_BID_PRICE,LAST_BID_SEQ_NBR,AMPLITUDE,SWITCHPOINT, DIRECTION into qa_last_ask_price,qa_last_ask_seq_nbr,qa_last_bid_price,qa_last_bid_seq_nbr,qa_amplitude,qa_switchpoint,qa_direction from S18336Pteam7.QUOTE_ADJUST where INSTRUMENT_ID=this_instrument;
        if this_ask_price > 0 then /* it is an ask*/

                update S18336Pteam7.QUOTE_ADJUST set LAST_ASK_PRICE=this_ask_price where INSTRUMENT_ID=this_instrument;
                update S18336Pteam7.QUOTE_ADJUST set LAST_ASK_SEQ_NBR=this_quote_seq_nbr where INSTRUMENT_ID=this_instrument;
                if qa_last_ask_price > 0 then /*not first ask for this inst*/

                        set this_ask_price=qa_last_ask_price+(ABS(this_ask_price-qa_last_ask_price)*qa_amplitude*qa_direction);
                    end if;


        else /*it is a bid*/
                update S18336Pteam7.QUOTE_ADJUST set LAST_BID_PRICE=this_bid_price where INSTRUMENT_ID=this_instrument;
                update S18336Pteam7.QUOTE_ADJUST set LAST_BID_SEQ_NBR=this_quote_seq_nbr where INSTRUMENT_ID=this_instrument;
                if qa_last_bid_price > 0 then /*not first bid for this inst*/

                        set this_bid_price=qa_last_bid_price+(ABS(this_bid_price-qa_last_bid_price)*qa_amplitude*qa_direction);
                    end if;

        end if;  /* end if this is an ask or a bid*/
/* in all cases check and reset switchpoint if needed reset amplitude and update dates*/
        if qa_switchpoint > 0 then

                        update S18336Pteam7.QUOTE_ADJUST set SWITCHPOINT=SWITCHPOINT-1 where INSTRUMENT_ID=this_instrument ;
                    else  /*switchpoint <=0, recalculate switchpoint and change direction */
                        update S18336Pteam7.QUOTE_ADJUST set SWITCHPOINT=ROUND((RAND()+.5)*450), DIRECTION=DIRECTION*-1 where INSTRUMENT_ID=this_instrument;
                end if;
        update S18336Pteam7.QUOTE_ADJUST set AMPLITUDE=(RAND()+ .5) where INSTRUMENT_ID=this_instrument;
        set this_quote_date=DATE_ADD(this_quote_date, INTERVAL 12 YEAR);
        set this_quote_time=DATE_ADD(this_quote_time, INTERVAL 12 YEAR);
/* now write out the record*/
        insert into S18336Pteam7.STOCK_QUOTE_FEED values(this_instrument, this_quote_date, this_quote_seq_nbr, this_trading_symbol, this_quote_time, this_ask_price, this_ask_size, this_bid_price, this_bid_size);
        set loopcount=loopcount+1;
        END LOOP;
close cur1;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `STOCK_QUOTE_FEED`
--

CREATE TABLE `STOCK_QUOTE_FEED` (
  `INSTRUMENT_ID` int(11) NOT NULL,
  `QUOTE_DATE` date NOT NULL,
  `QUOTE_SEQ_NBR` int(11) NOT NULL,
  `TRADING_SYMBOL` varchar(15) DEFAULT NULL,
  `QUOTE_TIME` datetime DEFAULT NULL,
  `ASK_PRICE` decimal(18,4) DEFAULT NULL,
  `ASK_SIZE` int(11) DEFAULT NULL,
  `BID_PRICE` decimal(18,4) DEFAULT NULL,
  `BID_SIZE` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `STOCK_QUOTE_FEED`
--

INSERT INTO `STOCK_QUOTE_FEED` (`INSTRUMENT_ID`, `QUOTE_DATE`, `QUOTE_SEQ_NBR`, `TRADING_SYMBOL`, `QUOTE_TIME`, `ASK_PRICE`, `ASK_SIZE`, `BID_PRICE`, `BID_SIZE`) VALUES
(0, '2017-02-08', 2, 'AAA', '2017-02-08 09:05:54', '0.0000', 0, '21.6061', 7800),
(0, '2017-02-08', 3, 'AAA', '2017-02-08 09:06:27', '0.0000', 0, '22.0300', 2800),
(0, '2017-02-08', 4, 'AAA', '2017-02-08 09:18:33', '0.0000', 0, '22.0300', 8600),
(0, '2017-02-08', 6, 'AAA', '2017-02-08 09:26:57', '21.3904', 9900, '0.0000', 0),
(0, '2017-02-08', 7, 'AAA', '2017-02-08 09:29:48', '0.0000', 0, '22.0300', 4700),
(0, '2017-02-08', 8, 'AAA', '2017-02-08 09:40:49', '0.0000', 0, '21.9253', 4700),
(0, '2017-02-08', 9, 'AAA', '2017-02-08 09:41:57', '0.0000', 0, '21.9600', 7500),
(0, '2017-02-08', 11, 'AAA', '2017-02-08 09:45:10', '21.9871', 100, '0.0000', 0),
(0, '2017-02-08', 15, 'AAA', '2017-02-08 10:03:05', '0.0000', 0, '21.9158', 7700),
(0, '2017-02-08', 16, 'AAA', '2017-02-08 10:09:12', '0.0000', 0, '21.8920', 8000),
(0, '2017-02-08', 17, 'AAA', '2017-02-08 10:13:14', '22.0000', 3300, '0.0000', 0),
(0, '2017-02-08', 19, 'AAA', '2017-02-08 10:23:03', '0.0000', 0, '21.8708', 9300),
(0, '2017-02-08', 20, 'AAA', '2017-02-08 10:29:06', '0.0000', 0, '21.9300', 5200),
(0, '2017-02-08', 21, 'AAA', '2017-02-08 10:31:59', '0.0000', 0, '21.8978', 8800),
(0, '2017-02-08', 22, 'AAA', '2017-02-08 10:32:26', '22.0000', 8800, '0.0000', 0),
(0, '2017-02-08', 24, 'AAA', '2017-02-08 10:36:57', '21.9029', 5800, '0.0000', 0),
(0, '2017-02-08', 25, 'AAA', '2017-02-08 10:37:30', '0.0000', 0, '21.8682', 9500),
(0, '2017-02-08', 27, 'AAA', '2017-02-08 10:48:56', '21.7078', 5700, '0.0000', 0),
(0, '2017-02-08', 29, 'AAA', '2017-02-08 10:49:45', '0.0000', 0, '21.8936', 9400),
(0, '2017-02-08', 34, 'AAA', '2017-02-08 11:03:10', '0.0000', 0, '21.9000', 9900),
(0, '2017-02-08', 35, 'AAA', '2017-02-08 11:03:20', '0.0000', 0, '21.8698', 2700),
(0, '2017-02-08', 38, 'AAA', '2017-02-08 11:13:45', '0.0000', 0, '21.9300', 7700),
(0, '2017-02-08', 39, 'AAA', '2017-02-08 11:13:47', '21.9152', 5200, '0.0000', 0),
(0, '2017-02-08', 40, 'AAA', '2017-02-08 11:19:31', '0.0000', 0, '21.8851', 5500),
(0, '2017-02-08', 41, 'AAA', '2017-02-08 11:26:10', '0.0000', 0, '21.9605', 500),
(0, '2017-02-08', 48, 'AAA', '2017-02-08 11:57:24', '21.7587', 400, '0.0000', 0),
(0, '2017-02-08', 50, 'AAA', '2017-02-08 12:03:49', '0.0000', 0, '22.0261', 3600),
(0, '2017-02-08', 53, 'AAA', '2017-02-08 12:06:45', '22.0360', 9400, '0.0000', 0),
(0, '2017-02-08', 55, 'AAA', '2017-02-08 12:11:06', '22.0223', 5300, '0.0000', 0),
(0, '2017-02-08', 56, 'AAA', '2017-02-08 12:14:06', '0.0000', 0, '22.0900', 3900),
(0, '2017-02-08', 57, 'AAA', '2017-02-08 12:27:19', '22.1500', 7600, '0.0000', 0),
(0, '2017-02-08', 60, 'AAA', '2017-02-08 12:51:08', '0.0000', 0, '22.0900', 9500),
(0, '2017-02-08', 61, 'AAA', '2017-02-08 12:52:54', '22.1176', 700, '0.0000', 0),
(0, '2017-02-08', 62, 'AAA', '2017-02-08 12:55:14', '22.1428', 7700, '0.0000', 0),
(0, '2017-02-08', 65, 'AAA', '2017-02-08 12:57:10', '22.0367', 1200, '0.0000', 0),
(0, '2017-02-08', 66, 'AAA', '2017-02-08 13:00:57', '22.1800', 7800, '0.0000', 0),
(0, '2017-02-08', 67, 'AAA', '2017-02-08 13:08:59', '22.1800', 6500, '0.0000', 0),
(0, '2017-02-08', 69, 'AAA', '2017-02-08 13:17:56', '22.1637', 4100, '0.0000', 0),
(0, '2017-02-08', 70, 'AAA', '2017-02-08 13:32:21', '0.0000', 0, '22.0900', 9000),
(0, '2017-02-08', 72, 'AAA', '2017-02-08 13:33:19', '0.0000', 0, '22.0900', 3900),
(0, '2017-02-08', 74, 'AAA', '2017-02-08 13:33:39', '22.1500', 8200, '0.0000', 0),
(0, '2017-02-08', 75, 'AAA', '2017-02-08 13:40:12', '22.1301', 8500, '0.0000', 0),
(0, '2017-02-08', 76, 'AAA', '2017-02-08 13:40:25', '22.1263', 3300, '0.0000', 0),
(0, '2017-02-08', 77, 'AAA', '2017-02-08 13:42:40', '0.0000', 0, '22.0640', 1700),
(0, '2017-02-08', 79, 'AAA', '2017-02-08 13:42:57', '0.0000', 0, '22.1200', 7300),
(0, '2017-02-08', 81, 'AAA', '2017-02-08 13:46:06', '21.9816', 4800, '0.0000', 0),
(0, '2017-02-08', 82, 'AAA', '2017-02-08 13:50:09', '22.1800', 2600, '0.0000', 0),
(0, '2017-02-08', 83, 'AAA', '2017-02-08 13:51:59', '22.1461', 400, '0.0000', 0),
(0, '2017-02-08', 85, 'AAA', '2017-02-08 13:56:02', '22.1119', 8300, '0.0000', 0),
(0, '2017-02-08', 90, 'AAA', '2017-02-08 14:10:43', '0.0000', 0, '22.0835', 3400),
(0, '2017-02-08', 92, 'AAA', '2017-02-08 14:24:35', '0.0000', 0, '22.1340', 9800),
(0, '2017-02-08', 93, 'AAA', '2017-02-08 14:31:01', '0.0000', 0, '22.1346', 1000),
(0, '2017-02-08', 94, 'AAA', '2017-02-08 14:34:14', '22.1552', 2000, '0.0000', 0),
(0, '2017-02-08', 95, 'AAA', '2017-02-08 14:41:26', '22.0687', 8500, '0.0000', 0),
(0, '2017-02-08', 98, 'AAA', '2017-02-08 14:45:41', '0.0000', 0, '22.1200', 8800),
(0, '2017-02-08', 99, 'AAA', '2017-02-08 14:47:53', '0.0000', 0, '22.0420', 8200),
(0, '2017-02-08', 100, 'AAA', '2017-02-08 14:50:23', '22.1676', 2500, '0.0000', 0),
(0, '2017-02-08', 101, 'AAA', '2017-02-08 14:51:40', '22.1500', 2300, '0.0000', 0),
(0, '2017-02-08', 102, 'AAA', '2017-02-08 14:55:17', '0.0000', 0, '22.0176', 9600),
(0, '2017-02-08', 103, 'AAA', '2017-02-08 14:57:18', '22.0488', 6500, '0.0000', 0),
(0, '2017-02-08', 107, 'AAA', '2017-02-08 15:03:59', '21.9228', 1200, '0.0000', 0),
(0, '2017-02-08', 111, 'AAA', '2017-02-08 15:34:03', '0.0000', 0, '22.0300', 200),
(0, '2017-02-08', 113, 'AAA', '2017-02-08 15:37:02', '22.1200', 500, '0.0000', 0),
(0, '2017-02-08', 117, 'AAA', '2017-02-08 15:46:52', '22.0850', 7600, '0.0000', 0),
(0, '2017-02-08', 118, 'AAA', '2017-02-08 15:55:02', '22.0659', 5900, '0.0000', 0),
(0, '2017-02-08', 123, 'AAA', '2017-02-08 16:22:30', '22.0600', 9000, '0.0000', 0),
(0, '2017-02-08', 124, 'AAA', '2017-02-08 16:32:51', '22.0358', 7800, '0.0000', 0),
(0, '2017-02-08', 125, 'AAA', '2017-02-08 16:36:01', '0.0000', 0, '21.9312', 1400),
(0, '2017-02-08', 126, 'AAA', '2017-02-08 16:40:57', '22.0266', 7300, '0.0000', 0),
(0, '2017-02-08', 127, 'AAA', '2017-02-08 16:44:27', '0.0000', 0, '21.9082', 4000),
(0, '2017-02-09', 129, 'AAA', '2017-02-09 09:03:08', '21.8907', 7400, '0.0000', 0),
(0, '2017-02-09', 131, 'AAA', '2017-02-09 09:08:29', '21.9020', 2300, '0.0000', 0),
(0, '2017-02-09', 132, 'AAA', '2017-02-09 09:12:52', '0.0000', 0, '21.8207', 8400),
(0, '2017-02-09', 133, 'AAA', '2017-02-09 09:17:12', '0.0000', 0, '21.9329', 8800),
(0, '2017-02-09', 135, 'AAA', '2017-02-09 09:25:08', '0.0000', 0, '21.9609', 5400),
(0, '2017-02-09', 136, 'AAA', '2017-02-09 09:28:34', '0.0000', 0, '21.9935', 300),
(0, '2017-02-09', 140, 'AAA', '2017-02-09 09:46:35', '0.0000', 0, '21.9820', 8200),
(0, '2017-02-09', 141, 'AAA', '2017-02-09 09:48:02', '0.0000', 0, '22.1200', 9500),
(0, '2017-02-09', 143, 'AAA', '2017-02-09 09:49:00', '0.0000', 0, '22.0355', 7800),
(0, '2017-02-09', 146, 'AAA', '2017-02-09 10:16:42', '0.0000', 0, '22.0132', 600),
(0, '2017-02-09', 148, 'AAA', '2017-02-09 10:19:01', '0.0000', 0, '21.9726', 7500),
(0, '2017-02-09', 149, 'AAA', '2017-02-09 10:19:09', '21.9600', 2900, '0.0000', 0),
(0, '2017-02-09', 150, 'AAA', '2017-02-09 10:20:06', '0.0000', 0, '21.9600', 2100),
(0, '2017-02-09', 152, 'AAA', '2017-02-09 10:26:36', '0.0000', 0, '21.9371', 6100),
(0, '2017-02-09', 154, 'AAA', '2017-02-09 10:37:43', '21.9237', 7000, '0.0000', 0),
(0, '2017-02-09', 155, 'AAA', '2017-02-09 10:41:35', '0.0000', 0, '21.8861', 9000),
(0, '2017-02-09', 158, 'AAA', '2017-02-09 10:50:19', '21.8550', 9800, '0.0000', 0),
(0, '2017-02-09', 159, 'AAA', '2017-02-09 10:57:46', '22.0000', 4900, '0.0000', 0),
(0, '2017-02-09', 165, 'AAA', '2017-02-09 11:24:34', '21.9626', 5200, '0.0000', 0),
(0, '2017-02-09', 166, 'AAA', '2017-02-09 11:31:53', '0.0000', 0, '21.8818', 6300),
(0, '2017-02-09', 170, 'AAA', '2017-02-09 11:48:00', '21.9600', 600, '0.0000', 0),
(0, '2017-02-09', 171, 'AAA', '2017-02-09 11:50:28', '21.8910', 1500, '0.0000', 0),
(0, '2017-02-09', 175, 'AAA', '2017-02-09 12:05:30', '21.8573', 7300, '0.0000', 0),
(0, '2017-02-09', 179, 'AAA', '2017-02-09 12:15:52', '0.0000', 0, '21.8700', 5500),
(0, '2017-02-09', 180, 'AAA', '2017-02-09 12:17:47', '0.0000', 0, '21.7993', 3000),
(0, '2017-02-09', 183, 'AAA', '2017-02-09 12:40:55', '0.0000', 0, '21.8924', 1400),
(0, '2017-02-09', 186, 'AAA', '2017-02-09 12:56:29', '21.8721', 8100, '0.0000', 0),
(0, '2017-02-09', 190, 'AAA', '2017-02-09 13:13:33', '0.0000', 0, '21.9423', 7700),
(0, '2017-02-09', 193, 'AAA', '2017-02-09 13:16:23', '0.0000', 0, '21.8426', 4100),
(0, '2017-02-09', 195, 'AAA', '2017-02-09 13:24:26', '0.0000', 0, '21.8361', 2800),
(0, '2017-02-09', 196, 'AAA', '2017-02-09 13:36:43', '0.0000', 0, '21.8604', 5000),
(0, '2017-02-09', 197, 'AAA', '2017-02-09 13:40:00', '0.0000', 0, '21.9740', 9500),
(0, '2017-02-09', 199, 'AAA', '2017-02-09 13:49:08', '21.9907', 1600, '0.0000', 0),
(0, '2017-02-09', 200, 'AAA', '2017-02-09 13:51:33', '21.9838', 7400, '0.0000', 0),
(0, '2017-02-09', 201, 'AAA', '2017-02-09 13:51:56', '0.0000', 0, '21.9367', 3800),
(0, '2017-02-09', 205, 'AAA', '2017-02-09 14:03:55', '0.0000', 0, '21.8870', 4800),
(0, '2017-02-09', 206, 'AAA', '2017-02-09 14:10:00', '21.9246', 8600, '0.0000', 0),
(0, '2017-02-09', 207, 'AAA', '2017-02-09 14:10:10', '0.0000', 0, '21.8738', 7400),
(0, '2017-02-09', 209, 'AAA', '2017-02-09 14:13:49', '0.0000', 0, '21.8909', 4400),
(0, '2017-02-09', 210, 'AAA', '2017-02-09 14:18:55', '0.0000', 0, '21.9600', 3800),
(0, '2017-02-09', 211, 'AAA', '2017-02-09 14:19:54', '0.0000', 0, '21.9600', 600),
(0, '2017-02-09', 212, 'AAA', '2017-02-09 14:25:17', '21.8850', 6800, '0.0000', 0),
(0, '2017-02-09', 214, 'AAA', '2017-02-09 14:33:10', '21.8309', 200, '0.0000', 0),
(0, '2017-02-09', 215, 'AAA', '2017-02-09 14:33:51', '0.0000', 0, '21.9600', 2100),
(0, '2017-02-09', 217, 'AAA', '2017-02-09 14:40:01', '21.9836', 8600, '0.0000', 0),
(0, '2017-02-09', 221, 'AAA', '2017-02-09 14:54:57', '0.0000', 0, '21.9092', 6600),
(0, '2017-02-09', 224, 'AAA', '2017-02-09 15:19:01', '22.0000', 9400, '0.0000', 0),
(0, '2017-02-09', 225, 'AAA', '2017-02-09 15:24:01', '0.0000', 0, '21.8646', 5300),
(0, '2017-02-09', 226, 'AAA', '2017-02-09 15:24:31', '21.8756', 2400, '0.0000', 0),
(0, '2017-02-09', 227, 'AAA', '2017-02-09 15:35:47', '21.8575', 3800, '0.0000', 0),
(0, '2017-02-09', 229, 'AAA', '2017-02-09 16:00:03', '0.0000', 0, '21.8252', 7400),
(0, '2017-02-09', 230, 'AAA', '2017-02-09 16:04:41', '0.0000', 0, '21.8615', 3400),
(0, '2017-02-09', 231, 'AAA', '2017-02-09 16:06:59', '21.8237', 7400, '0.0000', 0),
(0, '2017-02-09', 232, 'AAA', '2017-02-09 16:09:42', '0.0000', 0, '21.8548', 3200),
(0, '2017-02-09', 233, 'AAA', '2017-02-09 16:13:33', '21.9300', 8000, '0.0000', 0),
(0, '2017-02-09', 234, 'AAA', '2017-02-09 16:16:44', '21.9046', 4100, '0.0000', 0),
(0, '2017-02-09', 235, 'AAA', '2017-02-09 16:17:43', '0.0000', 0, '21.8131', 600),
(0, '2017-02-09', 237, 'AAA', '2017-02-09 16:19:37', '21.8581', 9000, '0.0000', 0),
(0, '2017-02-09', 238, 'AAA', '2017-02-09 16:24:48', '21.8707', 6000, '0.0000', 0),
(0, '2017-02-09', 239, 'AAA', '2017-02-09 16:30:05', '0.0000', 0, '21.7977', 5800),
(0, '2017-02-09', 240, 'AAA', '2017-02-09 16:37:40', '0.0000', 0, '21.8723', 8900),
(0, '2017-02-09', 241, 'AAA', '2017-02-09 16:38:11', '21.6670', 5600, '0.0000', 0),
(0, '2017-02-09', 242, 'AAA', '2017-02-09 16:38:32', '21.9771', 3300, '0.0000', 0),
(0, '2017-02-09', 244, 'AAA', '2017-02-09 16:47:07', '21.9300', 7300, '0.0000', 0),
(0, '2017-02-09', 246, 'AAA', '2017-02-09 16:47:25', '21.9300', 1200, '0.0000', 0),
(0, '2017-02-09', 247, 'AAA', '2017-02-09 16:54:57', '21.9300', 1200, '0.0000', 0),
(0, '2017-02-10', 250, 'AAA', '2017-02-10 09:04:12', '21.8639', 1600, '0.0000', 0),
(0, '2017-02-10', 251, 'AAA', '2017-02-10 09:06:25', '21.9635', 300, '0.0000', 0),
(0, '2017-02-10', 253, 'AAA', '2017-02-10 09:14:38', '0.0000', 0, '21.8906', 4600),
(0, '2017-02-10', 254, 'AAA', '2017-02-10 09:15:14', '21.8143', 3000, '0.0000', 0),
(0, '2017-02-10', 256, 'AAA', '2017-02-10 09:24:22', '0.0000', 0, '21.9043', 7200),
(0, '2017-02-10', 257, 'AAA', '2017-02-10 09:28:55', '0.0000', 0, '21.9428', 800),
(0, '2017-02-10', 258, 'AAA', '2017-02-10 09:39:52', '22.0176', 8200, '0.0000', 0),
(0, '2017-02-10', 263, 'AAA', '2017-02-10 10:12:54', '21.9728', 1400, '0.0000', 0),
(0, '2017-02-10', 269, 'AAA', '2017-02-10 10:41:17', '0.0000', 0, '21.9359', 600),
(0, '2017-02-10', 271, 'AAA', '2017-02-10 10:48:32', '21.9712', 6200, '0.0000', 0),
(0, '2017-02-10', 273, 'AAA', '2017-02-10 10:55:29', '22.0729', 8200, '0.0000', 0),
(0, '2017-02-10', 274, 'AAA', '2017-02-10 10:58:38', '0.0000', 0, '21.9473', 3400),
(0, '2017-02-10', 275, 'AAA', '2017-02-10 10:58:39', '0.0000', 0, '21.8711', 700),
(0, '2017-02-10', 276, 'AAA', '2017-02-10 11:04:04', '0.0000', 0, '21.9294', 6100),
(0, '2017-02-10', 278, 'AAA', '2017-02-10 11:12:00', '22.1490', 8900, '0.0000', 0),
(0, '2017-02-10', 280, 'AAA', '2017-02-10 11:16:06', '0.0000', 0, '21.9652', 7700),
(0, '2017-02-10', 285, 'AAA', '2017-02-10 11:43:25', '22.0869', 9800, '0.0000', 0),
(0, '2017-02-10', 286, 'AAA', '2017-02-10 11:44:35', '22.0600', 5300, '0.0000', 0),
(0, '2017-02-10', 288, 'AAA', '2017-02-10 11:59:55', '22.0873', 5800, '0.0000', 0),
(0, '2017-02-10', 289, 'AAA', '2017-02-10 12:02:04', '0.0000', 0, '22.0288', 700),
(0, '2017-02-10', 292, 'AAA', '2017-02-10 12:18:32', '0.0000', 0, '21.9414', 700),
(0, '2017-02-10', 293, 'AAA', '2017-02-10 12:26:40', '0.0000', 0, '21.8767', 9400),
(0, '2017-02-10', 296, 'AAA', '2017-02-10 12:33:58', '0.0000', 0, '21.7800', 8700),
(0, '2017-02-10', 297, 'AAA', '2017-02-10 12:37:11', '0.0000', 0, '21.8044', 8700),
(0, '2017-02-10', 302, 'AAA', '2017-02-10 12:58:55', '0.0000', 0, '21.7500', 9600),
(0, '2017-02-10', 303, 'AAA', '2017-02-10 13:05:21', '0.0000', 0, '21.8358', 8100),
(0, '2017-02-10', 307, 'AAA', '2017-02-10 13:19:42', '22.2967', 300, '0.0000', 0),
(0, '2017-02-10', 311, 'AAA', '2017-02-10 13:43:36', '21.8532', 1700, '0.0000', 0),
(0, '2017-02-10', 313, 'AAA', '2017-02-10 13:47:21', '21.9039', 6200, '0.0000', 0),
(0, '2017-02-10', 314, 'AAA', '2017-02-10 13:47:56', '0.0000', 0, '21.8939', 3200),
(0, '2017-02-10', 315, 'AAA', '2017-02-10 13:48:05', '0.0000', 0, '21.9092', 5200),
(0, '2017-02-10', 316, 'AAA', '2017-02-10 13:49:09', '0.0000', 0, '21.8671', 1000),
(0, '2017-02-10', 318, 'AAA', '2017-02-10 14:06:34', '21.8686', 3300, '0.0000', 0),
(0, '2017-02-10', 320, 'AAA', '2017-02-10 14:21:23', '0.0000', 0, '21.8251', 2900),
(0, '2017-02-10', 321, 'AAA', '2017-02-10 14:23:52', '21.8916', 2500, '0.0000', 0),
(0, '2017-02-10', 322, 'AAA', '2017-02-10 14:35:00', '21.8784', 4400, '0.0000', 0),
(0, '2017-02-10', 323, 'AAA', '2017-02-10 14:37:30', '21.9001', 300, '0.0000', 0),
(0, '2017-02-10', 324, 'AAA', '2017-02-10 14:39:54', '0.0000', 0, '21.7800', 4500),
(0, '2017-02-10', 328, 'AAA', '2017-02-10 14:51:07', '21.8400', 6800, '0.0000', 0),
(0, '2017-02-10', 329, 'AAA', '2017-02-10 14:58:11', '0.0000', 0, '21.7800', 900),
(0, '2017-02-10', 332, 'AAA', '2017-02-10 14:59:43', '0.0000', 0, '21.7800', 9300),
(0, '2017-02-10', 333, 'AAA', '2017-02-10 15:01:13', '21.8858', 5100, '0.0000', 0),
(0, '2017-02-10', 334, 'AAA', '2017-02-10 15:03:08', '0.0000', 0, '21.8137', 7700),
(0, '2017-02-10', 336, 'AAA', '2017-02-10 15:10:57', '21.9372', 6600, '0.0000', 0),
(0, '2017-02-10', 337, 'AAA', '2017-02-10 15:12:14', '0.0000', 0, '21.8400', 700),
(0, '2017-02-10', 338, 'AAA', '2017-02-10 15:13:29', '21.9283', 4600, '0.0000', 0),
(0, '2017-02-10', 339, 'AAA', '2017-02-10 15:21:50', '21.8700', 6800, '0.0000', 0),
(0, '2017-02-10', 344, 'AAA', '2017-02-10 15:36:58', '21.9003', 1000, '0.0000', 0),
(0, '2017-02-10', 345, 'AAA', '2017-02-10 15:49:18', '0.0000', 0, '21.8700', 4100),
(0, '2017-02-10', 347, 'AAA', '2017-02-10 15:52:23', '0.0000', 0, '21.9139', 5300),
(0, '2017-02-10', 353, 'AAA', '2017-02-10 16:26:14', '0.0000', 0, '21.9351', 9600),
(0, '2017-02-10', 354, 'AAA', '2017-02-10 16:26:40', '21.8590', 1800, '0.0000', 0),
(0, '2017-02-10', 355, 'AAA', '2017-02-10 16:30:51', '0.0000', 0, '21.8955', 3300),
(0, '2017-02-10', 356, 'AAA', '2017-02-10 16:32:43', '21.9007', 5800, '0.0000', 0),
(0, '2017-02-10', 357, 'AAA', '2017-02-10 16:35:25', '0.0000', 0, '21.9509', 7400),
(0, '2017-02-10', 359, 'AAA', '2017-02-10 16:56:02', '21.9999', 2900, '0.0000', 0),
(0, '2017-02-11', 362, 'AAA', '2017-02-11 09:15:12', '0.0000', 0, '22.0594', 1300),
(0, '2017-02-11', 365, 'AAA', '2017-02-11 09:22:22', '0.0000', 0, '22.0630', 400),
(0, '2017-02-11', 366, 'AAA', '2017-02-11 09:24:13', '0.0000', 0, '22.0262', 6100),
(0, '2017-02-11', 368, 'AAA', '2017-02-11 09:26:28', '0.0000', 0, '22.1092', 1000),
(0, '2017-02-11', 370, 'AAA', '2017-02-11 09:33:39', '22.0190', 5500, '0.0000', 0),
(0, '2017-02-11', 371, 'AAA', '2017-02-11 09:40:02', '0.0000', 0, '22.0323', 2000),
(0, '2017-02-11', 374, 'AAA', '2017-02-11 09:51:14', '22.1023', 9600, '0.0000', 0),
(0, '2017-02-11', 375, 'AAA', '2017-02-11 09:53:38', '21.9600', 7300, '0.0000', 0),
(0, '2017-02-11', 377, 'AAA', '2017-02-11 10:03:35', '21.9996', 6200, '0.0000', 0),
(0, '2017-02-11', 381, 'AAA', '2017-02-11 10:15:39', '21.9300', 9300, '0.0000', 0),
(0, '2017-02-11', 383, 'AAA', '2017-02-11 10:23:15', '0.0000', 0, '21.9360', 8200),
(0, '2017-02-11', 384, 'AAA', '2017-02-11 10:25:08', '21.9788', 5700, '0.0000', 0),
(0, '2017-02-11', 385, 'AAA', '2017-02-11 10:26:14', '0.0000', 0, '21.9107', 5600),
(0, '2017-02-11', 387, 'AAA', '2017-02-11 10:30:46', '22.0140', 6100, '0.0000', 0),
(0, '2017-02-11', 388, 'AAA', '2017-02-11 10:34:27', '22.0296', 6300, '0.0000', 0),
(0, '2017-02-11', 389, 'AAA', '2017-02-11 10:35:40', '0.0000', 0, '21.9518', 3500),
(0, '2017-02-11', 391, 'AAA', '2017-02-11 10:43:16', '22.0524', 1400, '0.0000', 0),
(0, '2017-02-11', 392, 'AAA', '2017-02-11 10:44:44', '0.0000', 0, '21.9600', 800),
(0, '2017-02-11', 394, 'AAA', '2017-02-11 11:02:34', '0.0000', 0, '21.9600', 8500),
(0, '2017-02-11', 395, 'AAA', '2017-02-11 11:08:57', '0.0000', 0, '22.0065', 7300),
(0, '2017-02-11', 396, 'AAA', '2017-02-11 11:12:09', '22.0600', 1600, '0.0000', 0),
(0, '2017-02-11', 397, 'AAA', '2017-02-11 11:25:46', '22.0957', 6700, '0.0000', 0),
(0, '2017-02-11', 398, 'AAA', '2017-02-11 11:27:53', '22.0000', 3300, '0.0000', 0),
(0, '2017-02-11', 401, 'AAA', '2017-02-11 12:00:38', '22.0843', 400, '0.0000', 0),
(0, '2017-02-11', 403, 'AAA', '2017-02-11 12:08:06', '0.0000', 0, '22.0000', 400),
(0, '2017-02-11', 406, 'AAA', '2017-02-11 12:15:07', '0.0000', 0, '22.0000', 6600),
(0, '2017-02-11', 407, 'AAA', '2017-02-11 12:17:34', '0.0000', 0, '22.0681', 600),
(0, '2017-02-11', 408, 'AAA', '2017-02-11 12:23:35', '22.1322', 6200, '0.0000', 0),
(0, '2017-02-11', 409, 'AAA', '2017-02-11 12:24:49', '22.1150', 3600, '0.0000', 0),
(0, '2017-02-11', 411, 'AAA', '2017-02-11 12:36:37', '22.2259', 6800, '0.0000', 0),
(0, '2017-02-11', 412, 'AAA', '2017-02-11 12:47:39', '22.0600', 6600, '0.0000', 0),
(0, '2017-02-11', 414, 'AAA', '2017-02-11 12:56:53', '22.0600', 5800, '0.0000', 0),
(0, '2017-02-11', 416, 'AAA', '2017-02-11 13:02:19', '0.0000', 0, '22.0600', 8800),
(0, '2017-02-11', 417, 'AAA', '2017-02-11 13:05:29', '22.0924', 2600, '0.0000', 0),
(0, '2017-02-11', 418, 'AAA', '2017-02-11 13:13:42', '22.0900', 1900, '0.0000', 0),
(0, '2017-02-11', 422, 'AAA', '2017-02-11 13:29:33', '0.0000', 0, '22.1363', 4300),
(0, '2017-02-11', 423, 'AAA', '2017-02-11 13:30:40', '0.0000', 0, '22.0291', 1700),
(0, '2017-02-11', 426, 'AAA', '2017-02-11 13:36:24', '22.1236', 2600, '0.0000', 0),
(0, '2017-02-11', 427, 'AAA', '2017-02-11 13:37:01', '22.0708', 9300, '0.0000', 0),
(0, '2017-02-11', 429, 'AAA', '2017-02-11 13:43:23', '0.0000', 0, '22.1329', 7600),
(0, '2017-02-11', 430, 'AAA', '2017-02-11 13:46:21', '0.0000', 0, '21.9600', 4800),
(0, '2017-02-11', 432, 'AAA', '2017-02-11 13:50:20', '22.1508', 7400, '0.0000', 0),
(0, '2017-02-11', 434, 'AAA', '2017-02-11 13:52:55', '0.0000', 0, '21.9998', 3800),
(0, '2017-02-11', 435, 'AAA', '2017-02-11 13:52:59', '22.0312', 6600, '0.0000', 0),
(0, '2017-02-11', 440, 'AAA', '2017-02-11 14:07:48', '0.0000', 0, '21.9597', 1900),
(0, '2017-02-11', 441, 'AAA', '2017-02-11 14:09:33', '22.1381', 1100, '0.0000', 0),
(0, '2017-02-11', 447, 'AAA', '2017-02-11 14:38:11', '0.0000', 0, '21.9322', 800),
(0, '2017-02-11', 449, 'AAA', '2017-02-11 14:44:21', '21.9702', 5900, '0.0000', 0),
(0, '2017-02-11', 450, 'AAA', '2017-02-11 14:45:22', '21.9354', 7400, '0.0000', 0),
(0, '2017-02-11', 451, 'AAA', '2017-02-11 14:46:27', '0.0000', 0, '21.8400', 7000),
(0, '2017-02-11', 455, 'AAA', '2017-02-11 15:08:32', '21.8400', 9400, '0.0000', 0),
(0, '2017-02-11', 456, 'AAA', '2017-02-11 15:17:07', '21.8962', 500, '0.0000', 0),
(0, '2017-02-11', 457, 'AAA', '2017-02-11 15:23:21', '0.0000', 0, '21.8400', 2100),
(0, '2017-02-11', 461, 'AAA', '2017-02-11 15:34:27', '0.0000', 0, '21.9293', 5700),
(0, '2017-02-11', 462, 'AAA', '2017-02-11 15:37:38', '0.0000', 0, '21.8026', 300),
(0, '2017-02-11', 465, 'AAA', '2017-02-11 15:43:02', '0.0000', 0, '21.7911', 5900),
(0, '2017-02-11', 466, 'AAA', '2017-02-11 15:45:54', '0.0000', 0, '21.6800', 8400),
(0, '2017-02-11', 467, 'AAA', '2017-02-11 15:47:27', '0.0000', 0, '21.6800', 7700),
(0, '2017-02-11', 469, 'AAA', '2017-02-11 16:05:12', '22.1393', 9000, '0.0000', 0),
(0, '2017-02-11', 470, 'AAA', '2017-02-11 16:05:25', '0.0000', 0, '21.7683', 2500),
(0, '2017-02-11', 471, 'AAA', '2017-02-11 16:06:16', '0.0000', 0, '21.8198', 7200),
(0, '2017-02-11', 472, 'AAA', '2017-02-11 16:07:58', '21.8825', 6400, '0.0000', 0),
(0, '2017-02-11', 473, 'AAA', '2017-02-11 16:23:12', '0.0000', 0, '21.8527', 9900),
(0, '2017-02-11', 474, 'AAA', '2017-02-11 16:26:12', '0.0000', 0, '21.7500', 8400),
(0, '2017-02-11', 475, 'AAA', '2017-02-11 16:26:44', '0.0000', 0, '21.7500', 3900),
(0, '2017-02-11', 477, 'AAA', '2017-02-11 16:39:11', '21.8826', 3700, '0.0000', 0),
(0, '2017-02-14', 486, 'AAA', '2017-02-14 09:14:16', '21.8775', 3400, '0.0000', 0),
(0, '2017-02-14', 489, 'AAA', '2017-02-14 09:20:10', '0.0000', 0, '21.7500', 2800),
(0, '2017-02-14', 491, 'AAA', '2017-02-14 09:37:55', '0.0000', 0, '21.7976', 2900),
(27, '2017-02-08', 4, 'ABB', '2017-02-08 09:14:32', '30.8842', 8300, '0.0000', 0),
(27, '2017-02-08', 6, 'ABB', '2017-02-08 09:20:36', '0.0000', 0, '31.0106', 9300),
(27, '2017-02-08', 7, 'ABB', '2017-02-08 09:41:01', '31.0267', 7600, '0.0000', 0),
(27, '2017-02-08', 9, 'ABB', '2017-02-08 09:47:16', '30.8914', 6300, '0.0000', 0),
(27, '2017-02-08', 12, 'ABB', '2017-02-08 10:01:31', '31.0733', 3900, '0.0000', 0),
(27, '2017-02-08', 13, 'ABB', '2017-02-08 10:01:48', '31.0288', 7600, '0.0000', 0),
(27, '2017-02-08', 18, 'ABB', '2017-02-08 10:32:10', '31.0221', 5400, '0.0000', 0),
(27, '2017-02-08', 20, 'ABB', '2017-02-08 10:40:37', '0.0000', 0, '30.9199', 8700),
(27, '2017-02-08', 25, 'ABB', '2017-02-08 10:53:38', '0.0000', 0, '31.0256', 6500),
(27, '2017-02-08', 26, 'ABB', '2017-02-08 10:56:44', '0.0000', 0, '31.0684', 900),
(27, '2017-02-08', 28, 'ABB', '2017-02-08 11:06:34', '0.0000', 0, '31.0312', 3300),
(27, '2017-02-08', 33, 'ABB', '2017-02-08 11:28:55', '30.9533', 1400, '0.0000', 0),
(27, '2017-02-08', 35, 'ABB', '2017-02-08 11:43:16', '31.0900', 400, '0.0000', 0),
(27, '2017-02-08', 36, 'ABB', '2017-02-08 11:47:27', '0.0000', 0, '30.9472', 3700),
(27, '2017-02-08', 37, 'ABB', '2017-02-08 11:48:31', '0.0000', 0, '30.9600', 8900),
(27, '2017-02-08', 39, 'ABB', '2017-02-08 11:49:46', '30.9648', 7100, '0.0000', 0),
(27, '2017-02-08', 41, 'ABB', '2017-02-08 11:56:49', '30.9600', 2300, '0.0000', 0),
(27, '2017-02-08', 42, 'ABB', '2017-02-08 11:59:36', '0.0000', 0, '30.9600', 2000),
(27, '2017-02-08', 46, 'ABB', '2017-02-08 12:04:36', '30.8670', 1600, '0.0000', 0),
(27, '2017-02-08', 50, 'ABB', '2017-02-08 12:21:35', '30.9779', 1300, '0.0000', 0),
(27, '2017-02-08', 52, 'ABB', '2017-02-08 12:29:21', '0.0000', 0, '30.9206', 9100),
(27, '2017-02-08', 53, 'ABB', '2017-02-08 12:37:53', '0.0000', 0, '30.8130', 2500),
(27, '2017-02-08', 54, 'ABB', '2017-02-08 12:49:56', '0.0000', 0, '30.9600', 7800),
(27, '2017-02-08', 55, 'ABB', '2017-02-08 12:52:28', '30.9600', 2500, '0.0000', 0),
(27, '2017-02-08', 58, 'ABB', '2017-02-08 13:18:57', '0.0000', 0, '30.9398', 9100),
(27, '2017-02-08', 60, 'ABB', '2017-02-08 13:35:04', '30.8062', 7600, '0.0000', 0),
(27, '2017-02-08', 61, 'ABB', '2017-02-08 13:38:29', '0.0000', 0, '31.0000', 7300),
(27, '2017-02-08', 63, 'ABB', '2017-02-08 13:55:27', '31.0538', 9300, '0.0000', 0),
(27, '2017-02-08', 64, 'ABB', '2017-02-08 13:55:47', '30.9730', 1000, '0.0000', 0),
(27, '2017-02-08', 65, 'ABB', '2017-02-08 14:12:15', '30.9845', 3800, '0.0000', 0),
(27, '2017-02-08', 66, 'ABB', '2017-02-08 14:16:41', '0.0000', 0, '31.0000', 2500),
(27, '2017-02-08', 68, 'ABB', '2017-02-08 15:01:24', '30.9903', 700, '0.0000', 0),
(27, '2017-02-08', 69, 'ABB', '2017-02-08 15:01:31', '0.0000', 0, '30.9697', 8000),
(27, '2017-02-08', 70, 'ABB', '2017-02-08 15:07:16', '0.0000', 0, '30.9609', 2800),
(27, '2017-02-08', 71, 'ABB', '2017-02-08 15:07:37', '31.0101', 100, '0.0000', 0),
(27, '2017-02-08', 72, 'ABB', '2017-02-08 15:09:52', '30.9600', 4500, '0.0000', 0),
(27, '2017-02-08', 74, 'ABB', '2017-02-08 15:17:09', '30.8548', 9200, '0.0000', 0),
(27, '2017-02-08', 76, 'ABB', '2017-02-08 15:42:00', '0.0000', 0, '30.9600', 5300),
(27, '2017-02-08', 77, 'ABB', '2017-02-08 15:45:19', '31.0386', 4000, '0.0000', 0),
(27, '2017-02-08', 79, 'ABB', '2017-02-08 15:50:12', '0.0000', 0, '30.9048', 5600),
(27, '2017-02-08', 80, 'ABB', '2017-02-08 15:52:13', '0.0000', 0, '30.9427', 2000),
(27, '2017-02-08', 83, 'ABB', '2017-02-08 16:12:13', '30.9060', 1400, '0.0000', 0),
(27, '2017-02-08', 87, 'ABB', '2017-02-08 16:20:56', '0.0000', 0, '31.0208', 7300),
(27, '2017-02-08', 88, 'ABB', '2017-02-08 16:25:14', '0.0000', 0, '31.0098', 2300),
(27, '2017-02-08', 89, 'ABB', '2017-02-08 16:31:40', '30.9868', 8100, '0.0000', 0),
(27, '2017-02-08', 91, 'ABB', '2017-02-08 16:34:04', '31.0300', 4300, '0.0000', 0),
(27, '2017-02-08', 93, 'ABB', '2017-02-08 16:36:52', '31.0300', 9900, '0.0000', 0),
(27, '2017-02-08', 96, 'ABB', '2017-02-08 16:50:39', '0.0000', 0, '30.9373', 3200),
(27, '2017-02-08', 98, 'ABB', '2017-02-08 16:59:53', '0.0000', 0, '30.9967', 4200),
(27, '2017-02-09', 101, 'ABB', '2017-02-09 09:09:44', '0.0000', 0, '30.9799', 2200),
(27, '2017-02-09', 106, 'ABB', '2017-02-09 09:22:54', '30.9933', 8300, '0.0000', 0),
(27, '2017-02-09', 107, 'ABB', '2017-02-09 09:29:39', '30.9737', 9400, '0.0000', 0),
(27, '2017-02-09', 109, 'ABB', '2017-02-09 09:40:19', '30.9258', 400, '0.0000', 0),
(27, '2017-02-09', 110, 'ABB', '2017-02-09 09:48:27', '0.0000', 0, '30.9600', 3200),
(27, '2017-02-09', 113, 'ABB', '2017-02-09 10:13:30', '30.9029', 6400, '0.0000', 0),
(27, '2017-02-09', 115, 'ABB', '2017-02-09 10:17:52', '31.0000', 3700, '0.0000', 0),
(27, '2017-02-09', 116, 'ABB', '2017-02-09 10:24:32', '31.0000', 100, '0.0000', 0),
(27, '2017-02-09', 117, 'ABB', '2017-02-09 10:29:14', '0.0000', 0, '30.9397', 3100),
(27, '2017-02-09', 119, 'ABB', '2017-02-09 10:32:37', '30.9251', 9200, '0.0000', 0),
(27, '2017-02-09', 123, 'ABB', '2017-02-09 10:48:05', '0.0000', 0, '30.9499', 6900),
(27, '2017-02-09', 127, 'ABB', '2017-02-09 11:12:43', '0.0000', 0, '30.8834', 7000),
(27, '2017-02-09', 129, 'ABB', '2017-02-09 11:14:37', '31.0607', 4800, '0.0000', 0),
(27, '2017-02-09', 130, 'ABB', '2017-02-09 11:15:47', '0.0000', 0, '31.0000', 2300),
(27, '2017-02-09', 131, 'ABB', '2017-02-09 11:17:39', '0.0000', 0, '31.0000', 5500),
(27, '2017-02-09', 133, 'ABB', '2017-02-09 11:21:25', '31.0600', 300, '0.0000', 0),
(27, '2017-02-09', 135, 'ABB', '2017-02-09 11:23:36', '0.0000', 0, '30.9841', 4400),
(27, '2017-02-09', 136, 'ABB', '2017-02-09 11:28:04', '31.0600', 1800, '0.0000', 0),
(27, '2017-02-09', 138, 'ABB', '2017-02-09 11:31:39', '0.0000', 0, '31.0034', 1800),
(27, '2017-02-09', 140, 'ABB', '2017-02-09 11:36:13', '31.0110', 2800, '0.0000', 0),
(27, '2017-02-09', 141, 'ABB', '2017-02-09 11:39:11', '0.0000', 0, '31.0600', 7400),
(27, '2017-02-09', 142, 'ABB', '2017-02-09 11:44:30', '0.0000', 0, '31.0385', 700),
(27, '2017-02-09', 144, 'ABB', '2017-02-09 11:48:23', '31.0831', 900, '0.0000', 0),
(27, '2017-02-09', 146, 'ABB', '2017-02-09 12:01:34', '31.1800', 7300, '0.0000', 0),
(27, '2017-02-09', 151, 'ABB', '2017-02-09 12:19:34', '31.1627', 2900, '0.0000', 0),
(27, '2017-02-09', 152, 'ABB', '2017-02-09 12:20:12', '0.0000', 0, '31.0900', 1700),
(27, '2017-02-09', 153, 'ABB', '2017-02-09 12:24:13', '31.1262', 7800, '0.0000', 0),
(27, '2017-02-09', 154, 'ABB', '2017-02-09 12:28:33', '31.1200', 1600, '0.0000', 0),
(27, '2017-02-09', 155, 'ABB', '2017-02-09 12:29:10', '0.0000', 0, '31.0900', 2600),
(27, '2017-02-09', 156, 'ABB', '2017-02-09 12:32:08', '0.0000', 0, '31.0392', 5700),
(27, '2017-02-09', 157, 'ABB', '2017-02-09 12:33:06', '0.0000', 0, '31.1216', 7400),
(27, '2017-02-09', 159, 'ABB', '2017-02-09 12:42:27', '31.0814', 8700, '0.0000', 0),
(27, '2017-02-09', 163, 'ABB', '2017-02-09 13:00:17', '0.0000', 0, '31.1200', 1500),
(27, '2017-02-09', 165, 'ABB', '2017-02-09 13:06:26', '0.0000', 0, '31.0854', 6600),
(27, '2017-02-09', 169, 'ABB', '2017-02-09 13:23:40', '0.0000', 0, '31.0497', 4200),
(27, '2017-02-09', 171, 'ABB', '2017-02-09 13:33:38', '31.1542', 5000, '0.0000', 0),
(27, '2017-02-09', 172, 'ABB', '2017-02-09 13:34:27', '0.0000', 0, '31.0642', 4100),
(27, '2017-02-09', 173, 'ABB', '2017-02-09 13:37:26', '0.0000', 0, '31.0900', 8200),
(27, '2017-02-09', 174, 'ABB', '2017-02-09 13:45:34', '0.0000', 0, '31.0046', 1300),
(27, '2017-02-09', 175, 'ABB', '2017-02-09 13:48:22', '31.1610', 2100, '0.0000', 0),
(27, '2017-02-09', 176, 'ABB', '2017-02-09 13:50:09', '0.0000', 0, '31.1500', 5500),
(27, '2017-02-09', 180, 'ABB', '2017-02-09 14:16:30', '31.2500', 3700, '0.0000', 0),
(27, '2017-02-09', 181, 'ABB', '2017-02-09 14:18:17', '0.0000', 0, '31.1500', 3500),
(27, '2017-02-09', 182, 'ABB', '2017-02-09 14:19:27', '0.0000', 0, '31.1135', 3300),
(27, '2017-02-09', 183, 'ABB', '2017-02-09 14:20:54', '31.2500', 1600, '0.0000', 0),
(27, '2017-02-09', 184, 'ABB', '2017-02-09 14:21:56', '31.2500', 1300, '0.0000', 0),
(27, '2017-02-09', 185, 'ABB', '2017-02-09 14:27:44', '0.0000', 0, '31.1558', 1500),
(27, '2017-02-09', 186, 'ABB', '2017-02-09 14:30:56', '31.2252', 7800, '0.0000', 0),
(27, '2017-02-09', 187, 'ABB', '2017-02-09 14:38:01', '31.2800', 1000, '0.0000', 0),
(27, '2017-02-09', 188, 'ABB', '2017-02-09 14:48:09', '31.2800', 500, '0.0000', 0),
(27, '2017-02-09', 189, 'ABB', '2017-02-09 14:51:11', '0.0000', 0, '31.1567', 5500),
(27, '2017-02-09', 190, 'ABB', '2017-02-09 14:51:15', '31.2288', 3700, '0.0000', 0),
(27, '2017-02-09', 192, 'ABB', '2017-02-09 14:52:25', '0.0000', 0, '31.1500', 6700),
(27, '2017-02-09', 194, 'ABB', '2017-02-09 14:54:17', '31.1047', 9700, '0.0000', 0),
(27, '2017-02-09', 197, 'ABB', '2017-02-09 15:23:44', '31.2281', 8700, '0.0000', 0),
(27, '2017-02-09', 198, 'ABB', '2017-02-09 15:25:51', '31.1746', 5000, '0.0000', 0),
(27, '2017-02-09', 200, 'ABB', '2017-02-09 15:26:09', '0.0000', 0, '31.0817', 2400),
(27, '2017-02-09', 203, 'ABB', '2017-02-09 15:29:23', '31.1135', 2700, '0.0000', 0),
(27, '2017-02-09', 204, 'ABB', '2017-02-09 15:35:26', '31.0790', 9800, '0.0000', 0),
(27, '2017-02-09', 205, 'ABB', '2017-02-09 15:42:47', '0.0000', 0, '31.0684', 1400),
(27, '2017-02-09', 206, 'ABB', '2017-02-09 15:43:26', '0.0000', 0, '31.0036', 6300),
(27, '2017-02-09', 207, 'ABB', '2017-02-09 15:44:41', '31.0906', 3600, '0.0000', 0),
(27, '2017-02-09', 208, 'ABB', '2017-02-09 15:58:52', '0.0000', 0, '30.9642', 1300),
(27, '2017-02-09', 209, 'ABB', '2017-02-09 15:59:21', '31.0210', 7500, '0.0000', 0),
(27, '2017-02-09', 210, 'ABB', '2017-02-09 16:00:29', '0.0000', 0, '31.0300', 5700),
(27, '2017-02-09', 211, 'ABB', '2017-02-09 16:02:27', '0.0000', 0, '31.0300', 700),
(27, '2017-02-09', 213, 'ABB', '2017-02-09 16:14:17', '31.0519', 5200, '0.0000', 0),
(27, '2017-02-09', 215, 'ABB', '2017-02-09 16:27:59', '0.0000', 0, '31.0067', 6000),
(27, '2017-02-09', 218, 'ABB', '2017-02-09 16:39:30', '0.0000', 0, '31.0353', 1000),
(27, '2017-02-09', 219, 'ABB', '2017-02-09 16:42:21', '31.0234', 2700, '0.0000', 0),
(27, '2017-02-09', 220, 'ABB', '2017-02-09 16:55:53', '0.0000', 0, '31.0260', 1900),
(27, '2017-02-10', 222, 'ABB', '2017-02-10 09:05:20', '0.0000', 0, '31.0300', 8300),
(27, '2017-02-10', 225, 'ABB', '2017-02-10 09:14:53', '0.0000', 0, '30.9871', 8600),
(27, '2017-02-10', 227, 'ABB', '2017-02-10 09:20:28', '31.0189', 1400, '0.0000', 0),
(27, '2017-02-10', 228, 'ABB', '2017-02-10 09:20:34', '30.9867', 1900, '0.0000', 0),
(27, '2017-02-10', 233, 'ABB', '2017-02-10 09:34:00', '31.0453', 3000, '0.0000', 0),
(27, '2017-02-10', 239, 'ABB', '2017-02-10 09:52:33', '0.0000', 0, '30.9341', 4000),
(27, '2017-02-10', 240, 'ABB', '2017-02-10 09:52:39', '0.0000', 0, '30.9996', 3600),
(27, '2017-02-10', 242, 'ABB', '2017-02-10 10:05:06', '0.0000', 0, '30.9829', 7300),
(27, '2017-02-10', 244, 'ABB', '2017-02-10 10:08:02', '0.0000', 0, '31.0300', 9400),
(27, '2017-02-10', 245, 'ABB', '2017-02-10 10:11:30', '31.0262', 3600, '0.0000', 0),
(27, '2017-02-10', 246, 'ABB', '2017-02-10 10:21:12', '0.0000', 0, '30.9939', 8400),
(27, '2017-02-10', 248, 'ABB', '2017-02-10 10:37:18', '0.0000', 0, '31.0600', 2900),
(27, '2017-02-10', 250, 'ABB', '2017-02-10 10:58:54', '31.0104', 100, '0.0000', 0),
(27, '2017-02-10', 256, 'ABB', '2017-02-10 11:28:46', '30.9821', 600, '0.0000', 0),
(27, '2017-02-10', 259, 'ABB', '2017-02-10 11:37:11', '0.0000', 0, '30.9942', 6600),
(27, '2017-02-10', 261, 'ABB', '2017-02-10 11:48:10', '0.0000', 0, '31.0799', 5700),
(27, '2017-02-10', 262, 'ABB', '2017-02-10 11:49:55', '31.1200', 8800, '0.0000', 0),
(27, '2017-02-10', 263, 'ABB', '2017-02-10 11:51:56', '0.0000', 0, '31.0601', 700),
(27, '2017-02-10', 266, 'ABB', '2017-02-10 12:10:38', '0.0000', 0, '31.1042', 4500),
(27, '2017-02-10', 268, 'ABB', '2017-02-10 12:22:23', '0.0000', 0, '31.1343', 5000),
(27, '2017-02-10', 269, 'ABB', '2017-02-10 12:27:08', '0.0000', 0, '31.1200', 3400),
(27, '2017-02-10', 270, 'ABB', '2017-02-10 12:27:40', '0.0000', 0, '31.0955', 8500),
(27, '2017-02-10', 272, 'ABB', '2017-02-10 12:35:52', '30.9599', 3700, '0.0000', 0),
(27, '2017-02-10', 273, 'ABB', '2017-02-10 12:36:23', '0.0000', 0, '31.1500', 600),
(27, '2017-02-10', 275, 'ABB', '2017-02-10 12:49:14', '0.0000', 0, '31.0675', 2400),
(27, '2017-02-10', 278, 'ABB', '2017-02-10 12:54:09', '31.2278', 1600, '0.0000', 0),
(27, '2017-02-10', 279, 'ABB', '2017-02-10 12:57:54', '0.0000', 0, '31.1582', 2300),
(27, '2017-02-10', 280, 'ABB', '2017-02-10 12:58:39', '31.0984', 6400, '0.0000', 0),
(27, '2017-02-10', 283, 'ABB', '2017-02-10 13:06:37', '31.3050', 1000, '0.0000', 0),
(27, '2017-02-10', 286, 'ABB', '2017-02-10 13:19:41', '31.3100', 600, '0.0000', 0),
(27, '2017-02-10', 287, 'ABB', '2017-02-10 13:22:29', '31.2696', 1000, '0.0000', 0),
(27, '2017-02-10', 288, 'ABB', '2017-02-10 13:35:06', '31.2593', 3700, '0.0000', 0),
(27, '2017-02-10', 289, 'ABB', '2017-02-10 13:40:20', '0.0000', 0, '31.2179', 6300),
(27, '2017-02-10', 290, 'ABB', '2017-02-10 13:41:39', '31.2500', 9800, '0.0000', 0),
(27, '2017-02-10', 291, 'ABB', '2017-02-10 13:41:51', '31.2500', 1500, '0.0000', 0),
(27, '2017-02-10', 293, 'ABB', '2017-02-10 13:45:35', '31.2166', 9900, '0.0000', 0),
(27, '2017-02-10', 297, 'ABB', '2017-02-10 13:55:07', '0.0000', 0, '31.2100', 6000),
(27, '2017-02-10', 298, 'ABB', '2017-02-10 13:57:13', '31.2398', 7400, '0.0000', 0),
(27, '2017-02-10', 302, 'ABB', '2017-02-10 14:08:45', '31.2500', 5400, '0.0000', 0),
(27, '2017-02-10', 303, 'ABB', '2017-02-10 14:15:06', '31.1855', 9600, '0.0000', 0),
(27, '2017-02-10', 304, 'ABB', '2017-02-10 14:27:34', '0.0000', 0, '31.1622', 7600),
(27, '2017-02-10', 305, 'ABB', '2017-02-10 14:40:08', '0.0000', 0, '31.1284', 7800),
(27, '2017-02-10', 307, 'ABB', '2017-02-10 15:04:04', '0.0000', 0, '31.1638', 8800),
(27, '2017-02-10', 309, 'ABB', '2017-02-10 15:16:41', '0.0000', 0, '31.1735', 6600),
(27, '2017-02-10', 311, 'ABB', '2017-02-10 15:23:13', '0.0000', 0, '31.1800', 4900),
(27, '2017-02-10', 313, 'ABB', '2017-02-10 15:26:23', '31.2651', 7500, '0.0000', 0),
(27, '2017-02-10', 314, 'ABB', '2017-02-10 15:26:45', '31.2192', 5400, '0.0000', 0),
(27, '2017-02-10', 315, 'ABB', '2017-02-10 15:27:49', '0.0000', 0, '31.0988', 1300),
(27, '2017-02-10', 317, 'ABB', '2017-02-10 15:31:11', '0.0000', 0, '31.2500', 3800),
(27, '2017-02-10', 318, 'ABB', '2017-02-10 15:32:58', '31.2402', 4500, '0.0000', 0),
(27, '2017-02-10', 319, 'ABB', '2017-02-10 15:40:12', '0.0000', 0, '31.2192', 800),
(27, '2017-02-10', 321, 'ABB', '2017-02-10 16:16:08', '31.3064', 700, '0.0000', 0),
(27, '2017-02-10', 323, 'ABB', '2017-02-10 16:20:02', '31.2784', 1700, '0.0000', 0),
(27, '2017-02-10', 326, 'ABB', '2017-02-10 16:32:28', '0.0000', 0, '31.2599', 9100),
(27, '2017-02-10', 327, 'ABB', '2017-02-10 16:33:27', '0.0000', 0, '31.1941', 1500),
(27, '2017-02-10', 331, 'ABB', '2017-02-10 16:53:04', '0.0000', 0, '31.1832', 1000),
(27, '2017-02-10', 333, 'ABB', '2017-02-10 16:57:54', '0.0000', 0, '31.1800', 5500),
(27, '2017-02-11', 335, 'ABB', '2017-02-11 09:10:08', '0.0000', 0, '31.0890', 7300),
(27, '2017-02-11', 336, 'ABB', '2017-02-11 09:15:41', '0.0000', 0, '31.2212', 6400),
(27, '2017-02-11', 338, 'ABB', '2017-02-11 09:19:05', '31.2356', 8500, '0.0000', 0),
(27, '2017-02-11', 339, 'ABB', '2017-02-11 09:20:03', '0.0000', 0, '31.2100', 2500),
(27, '2017-02-11', 340, 'ABB', '2017-02-11 09:26:47', '0.0000', 0, '31.2100', 3900),
(27, '2017-02-11', 342, 'ABB', '2017-02-11 09:30:26', '31.1715', 200, '0.0000', 0),
(27, '2017-02-11', 345, 'ABB', '2017-02-11 10:06:35', '0.0000', 0, '31.2100', 2300),
(27, '2017-02-11', 346, 'ABB', '2017-02-11 10:08:04', '0.0000', 0, '31.1812', 8500),
(27, '2017-02-11', 348, 'ABB', '2017-02-11 10:20:59', '0.0000', 0, '31.1800', 9000),
(27, '2017-02-11', 349, 'ABB', '2017-02-11 10:30:35', '0.0000', 0, '31.0964', 5200),
(27, '2017-02-11', 351, 'ABB', '2017-02-11 10:37:35', '0.0000', 0, '31.1960', 4000),
(27, '2017-02-11', 352, 'ABB', '2017-02-11 10:39:23', '0.0000', 0, '31.1378', 6900),
(27, '2017-02-11', 354, 'ABB', '2017-02-11 10:52:54', '0.0000', 0, '31.1500', 1100),
(27, '2017-02-11', 355, 'ABB', '2017-02-11 10:53:28', '0.0000', 0, '31.1042', 5100),
(27, '2017-02-11', 356, 'ABB', '2017-02-11 10:53:43', '31.1769', 3700, '0.0000', 0),
(27, '2017-02-11', 357, 'ABB', '2017-02-11 10:57:06', '0.0000', 0, '31.1507', 8900),
(27, '2017-02-11', 358, 'ABB', '2017-02-11 10:57:07', '31.1611', 4000, '0.0000', 0),
(27, '2017-02-11', 360, 'ABB', '2017-02-11 11:02:43', '31.0533', 4200, '0.0000', 0),
(27, '2017-02-11', 361, 'ABB', '2017-02-11 11:08:34', '0.0000', 0, '31.1147', 3300),
(27, '2017-02-11', 365, 'ABB', '2017-02-11 11:24:33', '31.1929', 3000, '0.0000', 0),
(27, '2017-02-11', 370, 'ABB', '2017-02-11 11:51:25', '31.1905', 9700, '0.0000', 0),
(27, '2017-02-11', 372, 'ABB', '2017-02-11 12:02:05', '0.0000', 0, '31.1611', 6000),
(27, '2017-02-11', 373, 'ABB', '2017-02-11 12:04:05', '31.1397', 3400, '0.0000', 0),
(27, '2017-02-11', 374, 'ABB', '2017-02-11 12:07:53', '0.0000', 0, '31.1283', 300),
(27, '2017-02-11', 376, 'ABB', '2017-02-11 12:12:26', '0.0000', 0, '31.2800', 2100),
(27, '2017-02-11', 380, 'ABB', '2017-02-11 12:19:41', '0.0000', 0, '31.2800', 4500),
(27, '2017-02-11', 381, 'ABB', '2017-02-11 12:19:42', '0.0000', 0, '31.2179', 9500),
(27, '2017-02-11', 385, 'ABB', '2017-02-11 12:31:16', '0.0000', 0, '31.3400', 9800),
(27, '2017-02-11', 387, 'ABB', '2017-02-11 12:44:47', '0.0000', 0, '31.3400', 200),
(27, '2017-02-11', 389, 'ABB', '2017-02-11 12:55:34', '0.0000', 0, '31.2750', 900),
(27, '2017-02-11', 390, 'ABB', '2017-02-11 13:08:53', '31.0734', 9500, '0.0000', 0),
(27, '2017-02-11', 391, 'ABB', '2017-02-11 13:09:46', '0.0000', 0, '31.3591', 1500),
(27, '2017-02-11', 393, 'ABB', '2017-02-11 13:15:04', '0.0000', 0, '31.4300', 8200),
(27, '2017-02-11', 394, 'ABB', '2017-02-11 13:15:07', '31.3877', 4100, '0.0000', 0),
(27, '2017-02-11', 396, 'ABB', '2017-02-11 13:19:36', '0.0000', 0, '31.4300', 5500),
(27, '2017-02-11', 397, 'ABB', '2017-02-11 13:21:39', '31.4359', 2500, '0.0000', 0),
(27, '2017-02-11', 398, 'ABB', '2017-02-11 13:29:58', '0.0000', 0, '31.3973', 2900),
(27, '2017-02-11', 399, 'ABB', '2017-02-11 13:44:39', '0.0000', 0, '31.4063', 1700),
(27, '2017-02-11', 401, 'ABB', '2017-02-11 13:46:39', '31.4561', 7800, '0.0000', 0),
(27, '2017-02-11', 404, 'ABB', '2017-02-11 14:01:21', '0.0000', 0, '31.5000', 9500),
(27, '2017-02-11', 405, 'ABB', '2017-02-11 14:15:16', '31.4647', 2900, '0.0000', 0),
(27, '2017-02-11', 406, 'ABB', '2017-02-11 14:30:58', '31.5512', 4900, '0.0000', 0),
(27, '2017-02-11', 407, 'ABB', '2017-02-11 14:31:40', '0.0000', 0, '31.5000', 7300),
(27, '2017-02-11', 412, 'ABB', '2017-02-11 14:38:15', '31.5600', 5000, '0.0000', 0),
(27, '2017-02-11', 417, 'ABB', '2017-02-11 15:10:27', '31.5600', 3500, '0.0000', 0),
(27, '2017-02-11', 418, 'ABB', '2017-02-11 15:11:33', '0.0000', 0, '31.4776', 4000),
(27, '2017-02-11', 420, 'ABB', '2017-02-11 15:14:06', '31.5248', 3100, '0.0000', 0),
(27, '2017-02-11', 421, 'ABB', '2017-02-11 15:14:47', '0.0000', 0, '31.4051', 3500),
(27, '2017-02-11', 422, 'ABB', '2017-02-11 15:18:12', '31.4434', 9800, '0.0000', 0),
(27, '2017-02-11', 424, 'ABB', '2017-02-11 15:33:47', '0.0000', 0, '31.4835', 5600),
(27, '2017-02-11', 428, 'ABB', '2017-02-11 15:49:50', '0.0000', 0, '31.5325', 3500),
(27, '2017-02-11', 430, 'ABB', '2017-02-11 15:58:49', '0.0000', 0, '31.4736', 3300),
(27, '2017-02-11', 433, 'ABB', '2017-02-11 16:17:56', '0.0000', 0, '31.4392', 5900),
(27, '2017-02-11', 437, 'ABB', '2017-02-11 16:32:29', '31.5057', 8200, '0.0000', 0),
(27, '2017-02-11', 439, 'ABB', '2017-02-11 16:33:57', '0.0000', 0, '31.4596', 2200),
(27, '2017-02-11', 441, 'ABB', '2017-02-11 16:37:26', '0.0000', 0, '31.4957', 5100),
(27, '2017-02-11', 445, 'ABB', '2017-02-11 16:54:30', '0.0000', 0, '31.5600', 7500),
(27, '2017-02-11', 447, 'ABB', '2017-02-11 16:59:14', '31.4583', 4200, '0.0000', 0),
(27, '2017-02-14', 449, 'ABB', '2017-02-14 09:03:11', '31.5179', 7500, '0.0000', 0),
(27, '2017-02-14', 450, 'ABB', '2017-02-14 09:04:08', '0.0000', 0, '31.5362', 3100),
(27, '2017-02-14', 453, 'ABB', '2017-02-14 09:19:04', '31.5667', 6800, '0.0000', 0),
(27, '2017-02-14', 454, 'ABB', '2017-02-14 09:25:10', '31.4937', 4600, '0.0000', 0),
(27, '2017-02-14', 455, 'ABB', '2017-02-14 09:29:00', '31.5299', 8600, '0.0000', 0),
(27, '2017-02-14', 460, 'ABB', '2017-02-14 09:37:17', '31.5900', 6000, '0.0000', 0),
(27, '2017-02-14', 461, 'ABB', '2017-02-14 09:41:23', '0.0000', 0, '31.4453', 6200),
(27, '2017-02-14', 462, 'ABB', '2017-02-14 09:43:47', '31.5020', 3400, '0.0000', 0),
(27, '2017-02-14', 464, 'ABB', '2017-02-14 09:45:06', '31.4336', 9400, '0.0000', 0),
(27, '2017-02-14', 466, 'ABB', '2017-02-14 09:57:55', '0.0000', 0, '31.4358', 5700),
(27, '2017-02-14', 467, 'ABB', '2017-02-14 10:00:19', '31.4560', 3500, '0.0000', 0),
(27, '2017-02-14', 469, 'ABB', '2017-02-14 10:08:32', '31.4325', 3000, '0.0000', 0),
(27, '2017-02-14', 472, 'ABB', '2017-02-14 10:21:22', '0.0000', 0, '31.4147', 5900),
(27, '2017-02-14', 473, 'ABB', '2017-02-14 10:23:50', '0.0000', 0, '31.4302', 600),
(27, '2017-02-14', 478, 'ABB', '2017-02-14 10:56:54', '0.0000', 0, '31.4492', 3900),
(27, '2017-02-14', 482, 'ABB', '2017-02-14 11:07:31', '0.0000', 0, '31.5236', 8800),
(27, '2017-02-14', 483, 'ABB', '2017-02-14 11:08:01', '0.0000', 0, '31.5583', 3500),
(27, '2017-02-14', 486, 'ABB', '2017-02-14 11:33:06', '0.0000', 0, '31.5300', 900),
(27, '2017-02-14', 488, 'ABB', '2017-02-14 11:44:48', '31.3193', 2000, '0.0000', 0),
(27, '2017-02-14', 489, 'ABB', '2017-02-14 11:51:59', '31.4899', 6600, '0.0000', 0),
(27, '2017-02-14', 490, 'ABB', '2017-02-14 11:53:13', '31.5911', 1600, '0.0000', 0),
(27, '2017-02-14', 491, 'ABB', '2017-02-14 12:08:36', '31.5337', 4100, '0.0000', 0),
(54, '2017-02-08', 1, 'ACC', '2017-02-08 09:01:11', '0.0000', 0, '39.4431', 5500),
(54, '2017-02-08', 2, 'ACC', '2017-02-08 09:08:08', '39.2167', 2500, '0.0000', 0),
(54, '2017-02-08', 6, 'ACC', '2017-02-08 09:14:00', '0.0000', 0, '38.0000', 4300),
(54, '2017-02-08', 7, 'ACC', '2017-02-08 09:34:57', '38.0895', 6600, '0.0000', 0),
(54, '2017-02-08', 9, 'ACC', '2017-02-08 09:38:50', '38.0595', 3600, '0.0000', 0),
(54, '2017-02-08', 11, 'ACC', '2017-02-08 09:45:42', '38.1276', 8100, '0.0000', 0),
(54, '2017-02-08', 15, 'ACC', '2017-02-08 09:54:53', '38.1072', 2000, '0.0000', 0),
(54, '2017-02-08', 16, 'ACC', '2017-02-08 09:57:59', '38.1210', 100, '0.0000', 0),
(54, '2017-02-08', 19, 'ACC', '2017-02-08 10:01:57', '0.0000', 0, '38.0446', 6600),
(54, '2017-02-08', 21, 'ACC', '2017-02-08 10:13:12', '38.1353', 3000, '0.0000', 0),
(54, '2017-02-08', 25, 'ACC', '2017-02-08 10:17:19', '38.1805', 9100, '0.0000', 0),
(54, '2017-02-08', 26, 'ACC', '2017-02-08 10:18:39', '0.0000', 0, '38.1034', 7000),
(54, '2017-02-08', 28, 'ACC', '2017-02-08 10:24:52', '38.0809', 800, '0.0000', 0),
(54, '2017-02-08', 32, 'ACC', '2017-02-08 10:43:42', '0.0000', 0, '38.0000', 2700),
(54, '2017-02-08', 34, 'ACC', '2017-02-08 10:56:53', '0.0000', 0, '38.0563', 7900),
(54, '2017-02-08', 40, 'ACC', '2017-02-08 11:17:32', '0.0000', 0, '37.9600', 8900),
(54, '2017-02-08', 41, 'ACC', '2017-02-08 11:21:30', '38.0710', 2400, '0.0000', 0),
(54, '2017-02-08', 43, 'ACC', '2017-02-08 11:27:52', '0.0000', 0, '38.0285', 8100),
(54, '2017-02-08', 44, 'ACC', '2017-02-08 11:30:29', '38.0801', 8800, '0.0000', 0),
(54, '2017-02-08', 45, 'ACC', '2017-02-08 11:44:44', '0.0000', 0, '38.0300', 4600),
(54, '2017-02-08', 46, 'ACC', '2017-02-08 12:00:28', '38.0900', 3700, '0.0000', 0),
(54, '2017-02-08', 48, 'ACC', '2017-02-08 12:13:45', '38.1285', 2100, '0.0000', 0),
(54, '2017-02-08', 49, 'ACC', '2017-02-08 12:22:12', '0.0000', 0, '38.0921', 800),
(54, '2017-02-08', 53, 'ACC', '2017-02-08 12:34:50', '0.0000', 0, '38.1668', 900),
(54, '2017-02-08', 57, 'ACC', '2017-02-08 12:46:21', '38.3171', 9300, '0.0000', 0),
(54, '2017-02-08', 59, 'ACC', '2017-02-08 12:58:35', '0.0000', 0, '38.1913', 1000),
(54, '2017-02-08', 60, 'ACC', '2017-02-08 13:01:30', '0.0000', 0, '38.1800', 7000),
(54, '2017-02-08', 61, 'ACC', '2017-02-08 13:02:01', '0.0000', 0, '38.1800', 5700),
(54, '2017-02-08', 64, 'ACC', '2017-02-08 13:24:40', '0.0000', 0, '38.1800', 9500),
(54, '2017-02-08', 66, 'ACC', '2017-02-08 13:37:30', '38.2500', 6400, '0.0000', 0),
(54, '2017-02-08', 70, 'ACC', '2017-02-08 13:57:18', '38.3069', 2700, '0.0000', 0),
(54, '2017-02-08', 71, 'ACC', '2017-02-08 14:07:09', '0.0000', 0, '38.2795', 6600),
(54, '2017-02-08', 72, 'ACC', '2017-02-08 14:13:52', '0.0000', 0, '38.2500', 9100),
(54, '2017-02-08', 74, 'ACC', '2017-02-08 14:15:11', '38.3526', 4600, '0.0000', 0),
(54, '2017-02-08', 75, 'ACC', '2017-02-08 14:28:37', '0.0000', 0, '38.2910', 5000),
(54, '2017-02-08', 77, 'ACC', '2017-02-08 14:32:07', '0.0000', 0, '38.2100', 5000),
(54, '2017-02-08', 78, 'ACC', '2017-02-08 14:32:46', '0.0000', 0, '38.2996', 9300),
(54, '2017-02-08', 79, 'ACC', '2017-02-08 14:33:44', '0.0000', 0, '38.3621', 1300),
(54, '2017-02-08', 82, 'ACC', '2017-02-08 14:44:43', '0.0000', 0, '38.3824', 4300),
(54, '2017-02-08', 84, 'ACC', '2017-02-08 14:46:06', '38.3662', 4100, '0.0000', 0),
(54, '2017-02-08', 85, 'ACC', '2017-02-08 14:55:59', '0.0000', 0, '38.4376', 4200),
(54, '2017-02-08', 86, 'ACC', '2017-02-08 15:01:12', '0.0000', 0, '38.3100', 7400),
(54, '2017-02-08', 89, 'ACC', '2017-02-08 15:08:19', '0.0000', 0, '38.3352', 2600),
(54, '2017-02-08', 90, 'ACC', '2017-02-08 15:08:39', '38.4051', 6000, '0.0000', 0),
(54, '2017-02-08', 91, 'ACC', '2017-02-08 15:22:18', '0.0000', 0, '38.2800', 6000),
(54, '2017-02-08', 96, 'ACC', '2017-02-08 15:50:21', '0.0000', 0, '38.3132', 4900),
(54, '2017-02-08', 97, 'ACC', '2017-02-08 15:51:41', '0.0000', 0, '38.2500', 9600),
(54, '2017-02-08', 98, 'ACC', '2017-02-08 15:57:35', '38.3770', 5500, '0.0000', 0),
(54, '2017-02-08', 99, 'ACC', '2017-02-08 16:03:32', '38.3400', 2600, '0.0000', 0),
(54, '2017-02-08', 102, 'ACC', '2017-02-08 16:38:30', '0.0000', 0, '38.2500', 4100),
(54, '2017-02-08', 103, 'ACC', '2017-02-08 16:42:56', '38.2813', 5700, '0.0000', 0),
(54, '2017-02-08', 104, 'ACC', '2017-02-08 16:56:08', '38.3594', 8000, '0.0000', 0),
(54, '2017-02-09', 106, 'ACC', '2017-02-09 09:02:56', '0.0000', 0, '38.2500', 3700),
(54, '2017-02-09', 107, 'ACC', '2017-02-09 09:06:02', '0.0000', 0, '38.2500', 800),
(54, '2017-02-09', 112, 'ACC', '2017-02-09 09:21:39', '38.4064', 9700, '0.0000', 0),
(54, '2017-02-09', 117, 'ACC', '2017-02-09 09:52:38', '0.0000', 0, '38.3143', 8600),
(54, '2017-02-09', 118, 'ACC', '2017-02-09 09:55:18', '0.0000', 0, '38.1800', 6000),
(54, '2017-02-09', 120, 'ACC', '2017-02-09 09:58:44', '38.3057', 500, '0.0000', 0),
(54, '2017-02-09', 122, 'ACC', '2017-02-09 10:07:46', '0.0000', 0, '38.1800', 100),
(54, '2017-02-09', 125, 'ACC', '2017-02-09 10:11:42', '0.0000', 0, '38.1800', 6600),
(54, '2017-02-09', 126, 'ACC', '2017-02-09 10:14:34', '38.3274', 8300, '0.0000', 0),
(54, '2017-02-09', 128, 'ACC', '2017-02-09 10:17:38', '38.1800', 4900, '0.0000', 0),
(54, '2017-02-09', 129, 'ACC', '2017-02-09 10:22:43', '38.1800', 3300, '0.0000', 0),
(54, '2017-02-09', 131, 'ACC', '2017-02-09 10:26:04', '38.3137', 6100, '0.0000', 0),
(54, '2017-02-09', 133, 'ACC', '2017-02-09 10:32:27', '38.3732', 3900, '0.0000', 0),
(54, '2017-02-09', 134, 'ACC', '2017-02-09 10:42:43', '0.0000', 0, '38.2492', 4700),
(54, '2017-02-09', 135, 'ACC', '2017-02-09 10:43:33', '38.3172', 8000, '0.0000', 0),
(54, '2017-02-09', 136, 'ACC', '2017-02-09 10:46:32', '38.3664', 4700, '0.0000', 0),
(54, '2017-02-09', 138, 'ACC', '2017-02-09 10:51:38', '0.0000', 0, '38.3012', 7900),
(54, '2017-02-09', 140, 'ACC', '2017-02-09 11:20:41', '0.0000', 0, '38.3025', 9200),
(54, '2017-02-09', 141, 'ACC', '2017-02-09 11:33:13', '38.3518', 8600, '0.0000', 0),
(54, '2017-02-09', 142, 'ACC', '2017-02-09 11:45:47', '0.0000', 0, '38.2800', 4400),
(54, '2017-02-09', 144, 'ACC', '2017-02-09 11:58:40', '0.0000', 0, '38.2800', 4000),
(54, '2017-02-09', 146, 'ACC', '2017-02-09 12:05:04', '38.3806', 9800, '0.0000', 0),
(54, '2017-02-09', 147, 'ACC', '2017-02-09 12:12:00', '38.4893', 2600, '0.0000', 0),
(54, '2017-02-09', 149, 'ACC', '2017-02-09 12:15:46', '0.0000', 0, '38.3219', 1900),
(54, '2017-02-09', 150, 'ACC', '2017-02-09 12:25:37', '0.0000', 0, '38.2792', 2900),
(54, '2017-02-09', 151, 'ACC', '2017-02-09 12:26:16', '0.0000', 0, '38.2800', 9900),
(54, '2017-02-09', 152, 'ACC', '2017-02-09 12:29:38', '38.3553', 8700, '0.0000', 0),
(54, '2017-02-09', 161, 'ACC', '2017-02-09 13:16:27', '38.3734', 1800, '0.0000', 0),
(54, '2017-02-09', 162, 'ACC', '2017-02-09 13:23:34', '38.5048', 4600, '0.0000', 0),
(54, '2017-02-09', 163, 'ACC', '2017-02-09 13:32:11', '0.0000', 0, '38.3173', 9500),
(54, '2017-02-09', 167, 'ACC', '2017-02-09 13:52:00', '38.3159', 2600, '0.0000', 0),
(54, '2017-02-09', 168, 'ACC', '2017-02-09 13:57:12', '0.0000', 0, '38.2618', 2300),
(54, '2017-02-09', 169, 'ACC', '2017-02-09 14:06:44', '0.0000', 0, '38.2800', 2600),
(54, '2017-02-09', 171, 'ACC', '2017-02-09 14:09:50', '0.0000', 0, '38.3054', 4700),
(54, '2017-02-09', 173, 'ACC', '2017-02-09 14:12:34', '0.0000', 0, '38.2825', 4500),
(54, '2017-02-09', 175, 'ACC', '2017-02-09 14:45:27', '0.0000', 0, '38.2420', 7800);
INSERT INTO `STOCK_QUOTE_FEED` (`INSTRUMENT_ID`, `QUOTE_DATE`, `QUOTE_SEQ_NBR`, `TRADING_SYMBOL`, `QUOTE_TIME`, `ASK_PRICE`, `ASK_SIZE`, `BID_PRICE`, `BID_SIZE`) VALUES
(54, '2017-02-09', 176, 'ACC', '2017-02-09 14:48:04', '0.0000', 0, '38.3279', 8100),
(54, '2017-02-09', 179, 'ACC', '2017-02-09 14:56:54', '38.2100', 6300, '0.0000', 0),
(54, '2017-02-09', 180, 'ACC', '2017-02-09 14:58:11', '0.0000', 0, '38.2117', 7900),
(54, '2017-02-09', 181, 'ACC', '2017-02-09 15:01:33', '0.0000', 0, '38.2100', 3500),
(54, '2017-02-09', 182, 'ACC', '2017-02-09 15:06:53', '0.0000', 0, '38.2498', 1100),
(54, '2017-02-09', 183, 'ACC', '2017-02-09 15:15:50', '38.2805', 5600, '0.0000', 0),
(54, '2017-02-09', 184, 'ACC', '2017-02-09 15:21:01', '0.0000', 0, '38.3118', 6800),
(54, '2017-02-09', 187, 'ACC', '2017-02-09 15:27:39', '38.3505', 8000, '0.0000', 0),
(54, '2017-02-09', 188, 'ACC', '2017-02-09 15:28:44', '0.0000', 0, '38.3540', 7400),
(54, '2017-02-09', 191, 'ACC', '2017-02-09 15:41:08', '38.3400', 6700, '0.0000', 0),
(54, '2017-02-09', 192, 'ACC', '2017-02-09 15:47:23', '0.0000', 0, '38.3451', 2700),
(54, '2017-02-09', 193, 'ACC', '2017-02-09 15:48:58', '0.0000', 0, '38.2100', 6500),
(54, '2017-02-09', 196, 'ACC', '2017-02-09 16:00:32', '0.0000', 0, '38.2399', 9900),
(54, '2017-02-09', 200, 'ACC', '2017-02-09 16:27:42', '38.3400', 8800, '0.0000', 0),
(54, '2017-02-09', 202, 'ACC', '2017-02-09 16:45:36', '38.3825', 6800, '0.0000', 0),
(54, '2017-02-09', 203, 'ACC', '2017-02-09 16:50:12', '38.3486', 6900, '0.0000', 0),
(54, '2017-02-09', 205, 'ACC', '2017-02-09 16:58:57', '38.3400', 200, '0.0000', 0),
(54, '2017-02-10', 207, 'ACC', '2017-02-10 09:00:34', '0.0000', 0, '38.2500', 7000),
(54, '2017-02-10', 208, 'ACC', '2017-02-10 09:01:01', '0.0000', 0, '38.2832', 3600),
(54, '2017-02-10', 210, 'ACC', '2017-02-10 09:09:49', '0.0000', 0, '38.3100', 7300),
(54, '2017-02-10', 212, 'ACC', '2017-02-10 09:29:10', '38.3829', 2100, '0.0000', 0),
(54, '2017-02-10', 214, 'ACC', '2017-02-10 09:38:31', '0.0000', 0, '38.3100', 7600),
(54, '2017-02-10', 215, 'ACC', '2017-02-10 09:38:51', '0.0000', 0, '38.3909', 6600),
(54, '2017-02-10', 216, 'ACC', '2017-02-10 09:42:22', '38.4624', 5600, '0.0000', 0),
(54, '2017-02-10', 220, 'ACC', '2017-02-10 09:56:03', '0.0000', 0, '38.3406', 2000),
(54, '2017-02-10', 223, 'ACC', '2017-02-10 10:02:06', '0.0000', 0, '38.2728', 6400),
(54, '2017-02-10', 227, 'ACC', '2017-02-10 10:12:14', '0.0000', 0, '38.2500', 7800),
(54, '2017-02-10', 231, 'ACC', '2017-02-10 10:45:57', '38.3779', 6400, '0.0000', 0),
(54, '2017-02-10', 237, 'ACC', '2017-02-10 11:21:36', '0.0000', 0, '38.3003', 9300),
(54, '2017-02-10', 242, 'ACC', '2017-02-10 11:50:41', '38.2800', 500, '0.0000', 0),
(54, '2017-02-10', 243, 'ACC', '2017-02-10 11:53:05', '0.0000', 0, '38.2250', 6900),
(54, '2017-02-10', 244, 'ACC', '2017-02-10 11:53:43', '0.0000', 0, '38.2791', 3200),
(54, '2017-02-10', 245, 'ACC', '2017-02-10 11:56:15', '38.3650', 9900, '0.0000', 0),
(54, '2017-02-10', 246, 'ACC', '2017-02-10 12:05:23', '38.3778', 4800, '0.0000', 0),
(54, '2017-02-10', 247, 'ACC', '2017-02-10 12:11:18', '38.5013', 1500, '0.0000', 0),
(54, '2017-02-10', 248, 'ACC', '2017-02-10 12:18:03', '0.0000', 0, '38.3228', 4700),
(54, '2017-02-10', 249, 'ACC', '2017-02-10 12:21:46', '38.4587', 2800, '0.0000', 0),
(54, '2017-02-10', 250, 'ACC', '2017-02-10 12:32:04', '0.0000', 0, '38.3690', 200),
(54, '2017-02-10', 251, 'ACC', '2017-02-10 12:39:13', '0.0000', 0, '38.3700', 3700),
(54, '2017-02-10', 252, 'ACC', '2017-02-10 12:43:19', '38.4193', 6600, '0.0000', 0),
(54, '2017-02-10', 253, 'ACC', '2017-02-10 12:47:16', '38.4767', 8400, '0.0000', 0),
(54, '2017-02-10', 254, 'ACC', '2017-02-10 12:49:47', '38.3700', 1700, '0.0000', 0),
(54, '2017-02-10', 255, 'ACC', '2017-02-10 12:55:49', '38.3700', 1800, '0.0000', 0),
(54, '2017-02-10', 256, 'ACC', '2017-02-10 12:56:46', '0.0000', 0, '38.3955', 3100),
(54, '2017-02-10', 257, 'ACC', '2017-02-10 12:57:02', '38.4609', 4200, '0.0000', 0),
(54, '2017-02-10', 258, 'ACC', '2017-02-10 13:05:15', '0.0000', 0, '38.4312', 5700),
(54, '2017-02-10', 259, 'ACC', '2017-02-10 13:11:43', '0.0000', 0, '38.3700', 5200),
(54, '2017-02-10', 264, 'ACC', '2017-02-10 13:21:15', '0.0000', 0, '38.3930', 1100),
(54, '2017-02-10', 265, 'ACC', '2017-02-10 13:21:30', '38.6330', 1500, '0.0000', 0),
(54, '2017-02-10', 266, 'ACC', '2017-02-10 13:28:56', '0.0000', 0, '38.4807', 7000),
(54, '2017-02-10', 268, 'ACC', '2017-02-10 13:32:46', '0.0000', 0, '38.3803', 6500),
(54, '2017-02-10', 272, 'ACC', '2017-02-10 14:00:25', '38.4259', 800, '0.0000', 0),
(54, '2017-02-10', 273, 'ACC', '2017-02-10 14:02:37', '38.3700', 5200, '0.0000', 0),
(54, '2017-02-10', 275, 'ACC', '2017-02-10 14:16:12', '0.0000', 0, '38.3700', 8600),
(54, '2017-02-10', 276, 'ACC', '2017-02-10 14:23:45', '0.0000', 0, '38.4099', 6200),
(54, '2017-02-10', 277, 'ACC', '2017-02-10 14:42:01', '0.0000', 0, '38.3400', 1200),
(54, '2017-02-10', 283, 'ACC', '2017-02-10 14:58:22', '38.3908', 5000, '0.0000', 0),
(54, '2017-02-10', 286, 'ACC', '2017-02-10 15:00:30', '38.4000', 6900, '0.0000', 0),
(54, '2017-02-10', 287, 'ACC', '2017-02-10 15:01:48', '38.4280', 1300, '0.0000', 0),
(54, '2017-02-10', 288, 'ACC', '2017-02-10 15:13:41', '38.4986', 4700, '0.0000', 0),
(54, '2017-02-10', 294, 'ACC', '2017-02-10 15:46:13', '0.0000', 0, '38.4291', 3900),
(54, '2017-02-10', 298, 'ACC', '2017-02-10 16:00:15', '38.4037', 2800, '0.0000', 0),
(54, '2017-02-10', 302, 'ACC', '2017-02-10 16:17:12', '0.0000', 0, '38.2800', 5300),
(54, '2017-02-10', 303, 'ACC', '2017-02-10 16:18:23', '38.3453', 3100, '0.0000', 0),
(54, '2017-02-10', 306, 'ACC', '2017-02-10 16:23:17', '0.0000', 0, '38.2800', 9400),
(54, '2017-02-10', 307, 'ACC', '2017-02-10 16:24:46', '38.3700', 8000, '0.0000', 0),
(54, '2017-02-10', 309, 'ACC', '2017-02-10 16:29:51', '38.4983', 2400, '0.0000', 0),
(54, '2017-02-10', 310, 'ACC', '2017-02-10 16:32:39', '38.3815', 7700, '0.0000', 0),
(54, '2017-02-10', 311, 'ACC', '2017-02-10 16:39:47', '0.0000', 0, '38.3362', 9500),
(54, '2017-02-11', 313, 'ACC', '2017-02-11 09:06:32', '38.4592', 2900, '0.0000', 0),
(54, '2017-02-11', 314, 'ACC', '2017-02-11 09:12:16', '38.3100', 9500, '0.0000', 0),
(54, '2017-02-11', 316, 'ACC', '2017-02-11 09:12:25', '38.3926', 4300, '0.0000', 0),
(54, '2017-02-11', 317, 'ACC', '2017-02-11 09:19:46', '0.0000', 0, '38.2100', 5700),
(54, '2017-02-11', 319, 'ACC', '2017-02-11 09:30:41', '0.0000', 0, '38.2100', 7100),
(54, '2017-02-11', 320, 'ACC', '2017-02-11 09:32:26', '38.2878', 9600, '0.0000', 0),
(54, '2017-02-11', 322, 'ACC', '2017-02-11 09:57:27', '0.0000', 0, '38.2669', 8200),
(54, '2017-02-11', 326, 'ACC', '2017-02-11 10:34:07', '0.0000', 0, '38.1929', 5700),
(54, '2017-02-11', 327, 'ACC', '2017-02-11 10:34:17', '0.0000', 0, '38.2100', 2300),
(54, '2017-02-11', 329, 'ACC', '2017-02-11 10:39:48', '0.0000', 0, '38.2589', 6800),
(54, '2017-02-11', 332, 'ACC', '2017-02-11 10:51:21', '0.0000', 0, '38.1909', 9900),
(54, '2017-02-11', 334, 'ACC', '2017-02-11 10:52:44', '0.0000', 0, '38.2269', 3500),
(54, '2017-02-11', 335, 'ACC', '2017-02-11 10:53:45', '0.0000', 0, '38.2901', 5300),
(54, '2017-02-11', 340, 'ACC', '2017-02-11 11:23:45', '38.3780', 8600, '0.0000', 0),
(54, '2017-02-11', 343, 'ACC', '2017-02-11 11:34:30', '38.4194', 9800, '0.0000', 0),
(54, '2017-02-11', 344, 'ACC', '2017-02-11 11:48:27', '0.0000', 0, '38.2800', 9500),
(54, '2017-02-11', 345, 'ACC', '2017-02-11 11:58:10', '0.0000', 0, '38.3186', 3700),
(54, '2017-02-11', 347, 'ACC', '2017-02-11 12:21:09', '38.4143', 500, '0.0000', 0),
(54, '2017-02-11', 348, 'ACC', '2017-02-11 12:23:57', '38.4170', 8900, '0.0000', 0),
(54, '2017-02-11', 351, 'ACC', '2017-02-11 12:31:19', '0.0000', 0, '38.3563', 1900),
(54, '2017-02-11', 353, 'ACC', '2017-02-11 12:58:16', '0.0000', 0, '38.4086', 300),
(54, '2017-02-11', 355, 'ACC', '2017-02-11 13:08:39', '0.0000', 0, '38.4598', 6500),
(54, '2017-02-11', 358, 'ACC', '2017-02-11 13:14:29', '38.4527', 2000, '0.0000', 0),
(54, '2017-02-11', 359, 'ACC', '2017-02-11 13:15:23', '0.0000', 0, '38.4976', 7100),
(54, '2017-02-11', 362, 'ACC', '2017-02-11 13:22:10', '0.0000', 0, '38.5596', 5800),
(54, '2017-02-11', 363, 'ACC', '2017-02-11 13:26:40', '0.0000', 0, '38.5836', 6700),
(54, '2017-02-11', 367, 'ACC', '2017-02-11 13:39:57', '0.0000', 0, '38.5900', 2800),
(54, '2017-02-11', 371, 'ACC', '2017-02-11 14:15:56', '0.0000', 0, '38.5900', 3600),
(54, '2017-02-11', 372, 'ACC', '2017-02-11 14:17:42', '38.6265', 9200, '0.0000', 0),
(54, '2017-02-11', 374, 'ACC', '2017-02-11 14:18:52', '0.0000', 0, '38.6773', 2400),
(54, '2017-02-11', 376, 'ACC', '2017-02-11 14:30:36', '38.6428', 6700, '0.0000', 0),
(54, '2017-02-11', 377, 'ACC', '2017-02-11 14:47:14', '38.5680', 5900, '0.0000', 0),
(54, '2017-02-11', 379, 'ACC', '2017-02-11 15:08:27', '0.0000', 0, '38.5842', 5900),
(54, '2017-02-11', 383, 'ACC', '2017-02-11 15:20:41', '38.5892', 7800, '0.0000', 0),
(54, '2017-02-11', 384, 'ACC', '2017-02-11 15:21:11', '38.5300', 3600, '0.0000', 0),
(54, '2017-02-11', 387, 'ACC', '2017-02-11 15:33:15', '38.5578', 5700, '0.0000', 0),
(54, '2017-02-11', 391, 'ACC', '2017-02-11 15:57:56', '0.0000', 0, '38.4600', 200),
(54, '2017-02-11', 393, 'ACC', '2017-02-11 16:00:51', '38.5000', 8500, '0.0000', 0),
(54, '2017-02-11', 394, 'ACC', '2017-02-11 16:00:55', '38.5000', 6000, '0.0000', 0),
(54, '2017-02-11', 395, 'ACC', '2017-02-11 16:01:40', '0.0000', 0, '38.4791', 6100),
(54, '2017-02-11', 396, 'ACC', '2017-02-11 16:02:42', '38.5187', 2400, '0.0000', 0),
(54, '2017-02-11', 397, 'ACC', '2017-02-11 16:03:41', '0.0000', 0, '38.4520', 4000),
(54, '2017-02-11', 398, 'ACC', '2017-02-11 16:05:28', '0.0000', 0, '38.4600', 8400),
(54, '2017-02-11', 400, 'ACC', '2017-02-11 16:13:55', '38.5719', 900, '0.0000', 0),
(54, '2017-02-11', 401, 'ACC', '2017-02-11 16:15:54', '0.0000', 0, '38.4600', 9800),
(54, '2017-02-11', 406, 'ACC', '2017-02-11 16:57:08', '0.0000', 0, '38.5038', 9500),
(54, '2017-02-14', 408, 'ACC', '2017-02-14 09:08:49', '38.5600', 5800, '0.0000', 0),
(54, '2017-02-14', 409, 'ACC', '2017-02-14 09:12:01', '38.6465', 7000, '0.0000', 0),
(54, '2017-02-14', 410, 'ACC', '2017-02-14 09:17:43', '38.6200', 2000, '0.0000', 0),
(54, '2017-02-14', 411, 'ACC', '2017-02-14 09:28:58', '38.7107', 2400, '0.0000', 0),
(54, '2017-02-14', 413, 'ACC', '2017-02-14 09:38:38', '0.0000', 0, '38.5300', 6100),
(54, '2017-02-14', 415, 'ACC', '2017-02-14 09:58:15', '0.0000', 0, '38.6241', 1000),
(54, '2017-02-14', 416, 'ACC', '2017-02-14 10:00:02', '38.5300', 6700, '0.0000', 0),
(54, '2017-02-14', 417, 'ACC', '2017-02-14 10:01:25', '38.5628', 5600, '0.0000', 0),
(54, '2017-02-14', 418, 'ACC', '2017-02-14 10:06:32', '0.0000', 0, '38.4600', 2300),
(54, '2017-02-14', 419, 'ACC', '2017-02-14 10:07:30', '0.0000', 0, '38.4600', 5700),
(54, '2017-02-14', 421, 'ACC', '2017-02-14 10:13:19', '38.5248', 8500, '0.0000', 0),
(54, '2017-02-14', 422, 'ACC', '2017-02-14 10:20:48', '0.0000', 0, '38.4944', 6800),
(54, '2017-02-14', 423, 'ACC', '2017-02-14 10:27:36', '38.6194', 7900, '0.0000', 0),
(54, '2017-02-14', 431, 'ACC', '2017-02-14 10:51:25', '38.6645', 4200, '0.0000', 0),
(54, '2017-02-14', 435, 'ACC', '2017-02-14 11:00:14', '38.5647', 4500, '0.0000', 0),
(54, '2017-02-14', 438, 'ACC', '2017-02-14 11:18:25', '0.0000', 0, '38.5699', 4500),
(54, '2017-02-14', 439, 'ACC', '2017-02-14 11:24:46', '0.0000', 0, '38.5600', 3400),
(54, '2017-02-14', 441, 'ACC', '2017-02-14 11:43:03', '38.5600', 5300, '0.0000', 0),
(54, '2017-02-14', 446, 'ACC', '2017-02-14 12:13:21', '38.5774', 9300, '0.0000', 0),
(54, '2017-02-14', 447, 'ACC', '2017-02-14 12:18:17', '38.6349', 2600, '0.0000', 0),
(54, '2017-02-14', 450, 'ACC', '2017-02-14 12:28:35', '38.6001', 400, '0.0000', 0),
(54, '2017-02-14', 451, 'ACC', '2017-02-14 12:35:14', '0.0000', 0, '38.5600', 5400),
(54, '2017-02-14', 452, 'ACC', '2017-02-14 12:54:34', '0.0000', 0, '38.5853', 9800),
(54, '2017-02-14', 453, 'ACC', '2017-02-14 12:55:53', '38.5900', 5400, '0.0000', 0),
(54, '2017-02-14', 456, 'ACC', '2017-02-14 13:10:59', '38.5900', 7800, '0.0000', 0),
(54, '2017-02-14', 457, 'ACC', '2017-02-14 13:14:54', '0.0000', 0, '38.6502', 9600),
(54, '2017-02-14', 459, 'ACC', '2017-02-14 13:23:05', '38.6460', 7300, '0.0000', 0),
(54, '2017-02-14', 460, 'ACC', '2017-02-14 13:23:22', '38.7383', 500, '0.0000', 0),
(54, '2017-02-14', 461, 'ACC', '2017-02-14 13:25:19', '38.7312', 8300, '0.0000', 0),
(54, '2017-02-14', 463, 'ACC', '2017-02-14 13:37:50', '38.7914', 2200, '0.0000', 0),
(54, '2017-02-14', 468, 'ACC', '2017-02-14 13:55:24', '0.0000', 0, '38.6764', 5600),
(54, '2017-02-14', 469, 'ACC', '2017-02-14 13:57:08', '0.0000', 0, '38.6800', 2700),
(54, '2017-02-14', 470, 'ACC', '2017-02-14 13:58:06', '38.6800', 3900, '0.0000', 0),
(54, '2017-02-14', 472, 'ACC', '2017-02-14 14:05:39', '0.0000', 0, '38.7170', 8900),
(54, '2017-02-14', 475, 'ACC', '2017-02-14 14:12:54', '0.0000', 0, '38.7512', 3400),
(54, '2017-02-14', 476, 'ACC', '2017-02-14 14:15:52', '38.6956', 7200, '0.0000', 0),
(54, '2017-02-14', 478, 'ACC', '2017-02-14 14:18:24', '0.0000', 0, '38.6500', 5400),
(54, '2017-02-14', 481, 'ACC', '2017-02-14 14:31:16', '38.7100', 6900, '0.0000', 0),
(54, '2017-02-14', 482, 'ACC', '2017-02-14 14:36:22', '38.7974', 7400, '0.0000', 0),
(54, '2017-02-14', 483, 'ACC', '2017-02-14 14:40:24', '38.6500', 6300, '0.0000', 0),
(54, '2017-02-14', 485, 'ACC', '2017-02-14 14:48:24', '0.0000', 0, '38.6685', 7100),
(54, '2017-02-14', 487, 'ACC', '2017-02-14 14:50:55', '0.0000', 0, '38.6200', 9300),
(54, '2017-02-14', 491, 'ACC', '2017-02-14 14:59:24', '38.6755', 7500, '0.0000', 0),
(81, '2017-02-08', 1, 'ADD', '2017-02-08 09:10:40', '0.0000', 0, '44.1940', 5400),
(81, '2017-02-08', 3, 'ADD', '2017-02-08 09:19:12', '44.0012', 900, '0.0000', 0),
(81, '2017-02-08', 7, 'ADD', '2017-02-08 09:35:45', '44.0600', 1600, '0.0000', 0),
(81, '2017-02-08', 8, 'ADD', '2017-02-08 09:42:44', '44.0320', 3900, '0.0000', 0),
(81, '2017-02-08', 9, 'ADD', '2017-02-08 09:43:45', '43.9789', 3400, '0.0000', 0),
(81, '2017-02-08', 16, 'ADD', '2017-02-08 10:13:44', '44.0439', 7100, '0.0000', 0),
(81, '2017-02-08', 19, 'ADD', '2017-02-08 10:32:33', '0.0000', 0, '44.0300', 4300),
(81, '2017-02-08', 24, 'ADD', '2017-02-08 11:13:10', '0.0000', 0, '44.0127', 9300),
(81, '2017-02-08', 25, 'ADD', '2017-02-08 11:15:04', '0.0000', 0, '44.0336', 3600),
(81, '2017-02-08', 30, 'ADD', '2017-02-08 11:31:36', '44.0197', 8900, '0.0000', 0),
(81, '2017-02-08', 31, 'ADD', '2017-02-08 11:41:43', '44.0423', 5900, '0.0000', 0),
(81, '2017-02-08', 33, 'ADD', '2017-02-08 11:53:27', '43.9130', 7500, '0.0000', 0),
(81, '2017-02-08', 34, 'ADD', '2017-02-08 11:57:32', '0.0000', 0, '43.9855', 1500),
(81, '2017-02-08', 37, 'ADD', '2017-02-08 12:08:00', '0.0000', 0, '44.0600', 2100),
(81, '2017-02-08', 38, 'ADD', '2017-02-08 12:13:31', '0.0000', 0, '44.0600', 900),
(81, '2017-02-08', 40, 'ADD', '2017-02-08 12:20:09', '44.0985', 5100, '0.0000', 0),
(81, '2017-02-08', 43, 'ADD', '2017-02-08 12:40:39', '44.1293', 2100, '0.0000', 0),
(81, '2017-02-08', 47, 'ADD', '2017-02-08 12:56:58', '0.0000', 0, '44.0079', 4600),
(81, '2017-02-08', 51, 'ADD', '2017-02-08 13:09:35', '0.0000', 0, '44.1200', 5700),
(81, '2017-02-08', 52, 'ADD', '2017-02-08 13:11:48', '0.0000', 0, '44.0370', 2900),
(81, '2017-02-08', 53, 'ADD', '2017-02-08 13:26:27', '0.0000', 0, '44.1800', 300),
(81, '2017-02-08', 54, 'ADD', '2017-02-08 13:38:45', '44.0689', 5300, '0.0000', 0),
(81, '2017-02-08', 55, 'ADD', '2017-02-08 13:43:14', '44.1444', 8300, '0.0000', 0),
(81, '2017-02-08', 57, 'ADD', '2017-02-08 13:49:18', '0.0000', 0, '44.1530', 8500),
(81, '2017-02-08', 58, 'ADD', '2017-02-08 14:01:24', '0.0000', 0, '44.2100', 6000),
(81, '2017-02-08', 59, 'ADD', '2017-02-08 14:03:14', '0.0000', 0, '44.2100', 4700),
(81, '2017-02-08', 60, 'ADD', '2017-02-08 14:06:10', '0.0000', 0, '44.1211', 7700),
(81, '2017-02-08', 62, 'ADD', '2017-02-08 14:11:02', '0.0000', 0, '44.2611', 7600),
(81, '2017-02-08', 63, 'ADD', '2017-02-08 14:15:08', '44.2253', 3400, '0.0000', 0),
(81, '2017-02-08', 65, 'ADD', '2017-02-08 14:19:00', '0.0000', 0, '44.2500', 4900),
(81, '2017-02-08', 67, 'ADD', '2017-02-08 14:25:06', '0.0000', 0, '44.2500', 9100),
(81, '2017-02-08', 69, 'ADD', '2017-02-08 14:33:38', '44.2063', 8800, '0.0000', 0),
(81, '2017-02-08', 70, 'ADD', '2017-02-08 14:38:28', '0.0000', 0, '44.2500', 6200),
(81, '2017-02-08', 72, 'ADD', '2017-02-08 14:42:48', '44.2792', 1200, '0.0000', 0),
(81, '2017-02-08', 73, 'ADD', '2017-02-08 14:44:29', '44.1801', 1800, '0.0000', 0),
(81, '2017-02-08', 75, 'ADD', '2017-02-08 14:51:04', '44.3100', 9100, '0.0000', 0),
(81, '2017-02-08', 76, 'ADD', '2017-02-08 14:54:09', '0.0000', 0, '44.2500', 6600),
(81, '2017-02-08', 77, 'ADD', '2017-02-08 14:58:16', '44.2522', 2100, '0.0000', 0),
(81, '2017-02-08', 81, 'ADD', '2017-02-08 15:18:06', '44.2097', 7000, '0.0000', 0),
(81, '2017-02-08', 82, 'ADD', '2017-02-08 15:19:43', '44.2378', 1500, '0.0000', 0),
(81, '2017-02-08', 86, 'ADD', '2017-02-08 15:31:56', '44.2263', 9500, '0.0000', 0),
(81, '2017-02-08', 87, 'ADD', '2017-02-08 15:34:17', '0.0000', 0, '44.2169', 800),
(81, '2017-02-08', 88, 'ADD', '2017-02-08 15:38:39', '0.0000', 0, '44.2800', 700),
(81, '2017-02-08', 89, 'ADD', '2017-02-08 15:47:53', '44.2800', 7700, '0.0000', 0),
(81, '2017-02-08', 92, 'ADD', '2017-02-08 15:53:35', '44.1651', 9000, '0.0000', 0),
(81, '2017-02-08', 93, 'ADD', '2017-02-08 16:04:44', '0.0000', 0, '44.2800', 6600),
(81, '2017-02-08', 95, 'ADD', '2017-02-08 16:13:16', '44.3263', 1400, '0.0000', 0),
(81, '2017-02-08', 96, 'ADD', '2017-02-08 16:15:00', '0.0000', 0, '44.2465', 1500),
(81, '2017-02-08', 97, 'ADD', '2017-02-08 16:22:17', '44.2937', 5300, '0.0000', 0),
(81, '2017-02-08', 98, 'ADD', '2017-02-08 16:22:20', '44.2050', 9200, '0.0000', 0),
(81, '2017-02-08', 99, 'ADD', '2017-02-08 16:27:33', '44.2140', 3900, '0.0000', 0),
(81, '2017-02-08', 101, 'ADD', '2017-02-08 16:31:44', '44.2487', 700, '0.0000', 0),
(81, '2017-02-08', 104, 'ADD', '2017-02-08 16:42:01', '0.0000', 0, '44.2500', 3200),
(81, '2017-02-08', 106, 'ADD', '2017-02-08 16:59:15', '44.2173', 7100, '0.0000', 0),
(81, '2017-02-09', 110, 'ADD', '2017-02-09 09:07:49', '0.0000', 0, '44.2500', 6300),
(81, '2017-02-09', 111, 'ADD', '2017-02-09 09:08:58', '0.0000', 0, '44.2500', 6700),
(81, '2017-02-09', 113, 'ADD', '2017-02-09 09:18:52', '44.3100', 7900, '0.0000', 0),
(81, '2017-02-09', 114, 'ADD', '2017-02-09 09:21:55', '44.2925', 8600, '0.0000', 0),
(81, '2017-02-09', 115, 'ADD', '2017-02-09 09:26:31', '0.0000', 0, '44.2500', 1700),
(81, '2017-02-09', 116, 'ADD', '2017-02-09 09:26:41', '44.2360', 8000, '0.0000', 0),
(81, '2017-02-09', 117, 'ADD', '2017-02-09 09:39:21', '44.2500', 2600, '0.0000', 0),
(81, '2017-02-09', 118, 'ADD', '2017-02-09 09:39:40', '44.2202', 4200, '0.0000', 0),
(81, '2017-02-09', 121, 'ADD', '2017-02-09 09:55:43', '0.0000', 0, '44.2094', 4500),
(81, '2017-02-09', 124, 'ADD', '2017-02-09 10:01:49', '44.2520', 2500, '0.0000', 0),
(81, '2017-02-09', 128, 'ADD', '2017-02-09 10:07:21', '44.2933', 4700, '0.0000', 0),
(81, '2017-02-09', 134, 'ADD', '2017-02-09 10:32:01', '0.0000', 0, '44.2074', 7800),
(81, '2017-02-09', 135, 'ADD', '2017-02-09 10:32:47', '0.0000', 0, '44.3400', 7000),
(81, '2017-02-09', 136, 'ADD', '2017-02-09 10:35:28', '0.0000', 0, '44.3098', 1900),
(81, '2017-02-09', 138, 'ADD', '2017-02-09 10:39:26', '44.3400', 2500, '0.0000', 0),
(81, '2017-02-09', 139, 'ADD', '2017-02-09 10:46:08', '44.3071', 6800, '0.0000', 0),
(81, '2017-02-09', 144, 'ADD', '2017-02-09 11:05:56', '44.3514', 8800, '0.0000', 0),
(81, '2017-02-09', 148, 'ADD', '2017-02-09 11:32:20', '44.3061', 9300, '0.0000', 0),
(81, '2017-02-09', 152, 'ADD', '2017-02-09 11:40:20', '0.0000', 0, '44.3100', 3900),
(81, '2017-02-09', 153, 'ADD', '2017-02-09 11:42:51', '44.2394', 1700, '0.0000', 0),
(81, '2017-02-09', 154, 'ADD', '2017-02-09 11:50:39', '0.0000', 0, '44.2686', 5300),
(81, '2017-02-09', 155, 'ADD', '2017-02-09 11:51:21', '0.0000', 0, '44.3099', 2700),
(81, '2017-02-09', 156, 'ADD', '2017-02-09 11:51:22', '44.3488', 2600, '0.0000', 0),
(81, '2017-02-09', 162, 'ADD', '2017-02-09 12:07:59', '44.4162', 1100, '0.0000', 0),
(81, '2017-02-09', 163, 'ADD', '2017-02-09 12:08:24', '44.3386', 4900, '0.0000', 0),
(81, '2017-02-09', 165, 'ADD', '2017-02-09 12:16:46', '0.0000', 0, '44.3550', 6400),
(81, '2017-02-09', 166, 'ADD', '2017-02-09 12:17:08', '0.0000', 0, '44.3100', 2100),
(81, '2017-02-09', 167, 'ADD', '2017-02-09 12:26:10', '44.3954', 7000, '0.0000', 0),
(81, '2017-02-09', 168, 'ADD', '2017-02-09 12:33:39', '44.3421', 2800, '0.0000', 0),
(81, '2017-02-09', 171, 'ADD', '2017-02-09 13:04:43', '0.0000', 0, '44.3100', 7600),
(81, '2017-02-09', 175, 'ADD', '2017-02-09 13:23:59', '0.0000', 0, '44.2916', 200),
(81, '2017-02-09', 176, 'ADD', '2017-02-09 13:29:20', '0.0000', 0, '44.2811', 1900),
(81, '2017-02-09', 178, 'ADD', '2017-02-09 13:33:57', '44.2286', 8900, '0.0000', 0),
(81, '2017-02-09', 180, 'ADD', '2017-02-09 13:35:24', '0.0000', 0, '44.3533', 9200),
(81, '2017-02-09', 181, 'ADD', '2017-02-09 13:39:38', '0.0000', 0, '44.3224', 6500),
(81, '2017-02-09', 182, 'ADD', '2017-02-09 13:45:07', '0.0000', 0, '44.2798', 8700),
(81, '2017-02-09', 187, 'ADD', '2017-02-09 14:03:38', '0.0000', 0, '44.3400', 9500),
(81, '2017-02-09', 190, 'ADD', '2017-02-09 14:07:34', '0.0000', 0, '44.3076', 3000),
(81, '2017-02-09', 191, 'ADD', '2017-02-09 14:16:10', '0.0000', 0, '44.2055', 2500),
(81, '2017-02-09', 192, 'ADD', '2017-02-09 14:16:17', '0.0000', 0, '44.2505', 6800),
(81, '2017-02-09', 195, 'ADD', '2017-02-09 14:36:33', '0.0000', 0, '44.4000', 8400),
(81, '2017-02-09', 196, 'ADD', '2017-02-09 14:38:39', '0.0000', 0, '44.3504', 9000),
(81, '2017-02-09', 197, 'ADD', '2017-02-09 14:38:41', '0.0000', 0, '44.3017', 2200),
(81, '2017-02-09', 199, 'ADD', '2017-02-09 15:10:36', '0.0000', 0, '44.3100', 4300),
(81, '2017-02-09', 201, 'ADD', '2017-02-09 15:25:36', '0.0000', 0, '44.3100', 200),
(81, '2017-02-09', 204, 'ADD', '2017-02-09 15:46:21', '0.0000', 0, '44.3100', 5200),
(81, '2017-02-09', 206, 'ADD', '2017-02-09 15:51:25', '0.0000', 0, '44.3100', 4900),
(81, '2017-02-09', 208, 'ADD', '2017-02-09 15:53:44', '0.0000', 0, '44.3100', 1000),
(81, '2017-02-09', 210, 'ADD', '2017-02-09 16:01:31', '44.3977', 900, '0.0000', 0),
(81, '2017-02-09', 211, 'ADD', '2017-02-09 16:01:33', '44.3542', 9300, '0.0000', 0),
(81, '2017-02-09', 212, 'ADD', '2017-02-09 16:01:37', '44.3144', 3400, '0.0000', 0),
(81, '2017-02-09', 214, 'ADD', '2017-02-09 16:35:47', '0.0000', 0, '44.2414', 4700),
(81, '2017-02-09', 215, 'ADD', '2017-02-09 16:40:41', '0.0000', 0, '44.1907', 8500),
(81, '2017-02-09', 217, 'ADD', '2017-02-09 16:46:10', '44.2618', 7200, '0.0000', 0),
(81, '2017-02-09', 218, 'ADD', '2017-02-09 16:47:27', '44.3444', 3700, '0.0000', 0),
(81, '2017-02-09', 219, 'ADD', '2017-02-09 16:54:54', '0.0000', 0, '44.2473', 8600),
(81, '2017-02-10', 223, 'ADD', '2017-02-10 09:12:21', '44.3791', 2200, '0.0000', 0),
(81, '2017-02-10', 225, 'ADD', '2017-02-10 09:22:17', '0.0000', 0, '44.3310', 3100),
(81, '2017-02-10', 228, 'ADD', '2017-02-10 09:30:01', '44.3492', 8500, '0.0000', 0),
(81, '2017-02-10', 232, 'ADD', '2017-02-10 09:47:51', '0.0000', 0, '44.3400', 9300),
(81, '2017-02-10', 234, 'ADD', '2017-02-10 09:56:56', '0.0000', 0, '44.3400', 7400),
(81, '2017-02-10', 236, 'ADD', '2017-02-10 10:03:05', '0.0000', 0, '44.3400', 2900),
(81, '2017-02-10', 239, 'ADD', '2017-02-10 10:31:34', '0.0000', 0, '44.3059', 1800),
(81, '2017-02-10', 240, 'ADD', '2017-02-10 10:32:47', '44.3546', 9700, '0.0000', 0),
(81, '2017-02-10', 241, 'ADD', '2017-02-10 10:33:44', '44.4436', 5100, '0.0000', 0),
(81, '2017-02-10', 243, 'ADD', '2017-02-10 10:40:53', '0.0000', 0, '44.3550', 6400),
(81, '2017-02-10', 257, 'ADD', '2017-02-10 11:34:39', '44.3856', 5400, '0.0000', 0),
(81, '2017-02-10', 259, 'ADD', '2017-02-10 11:45:50', '0.0000', 0, '44.2841', 3200),
(81, '2017-02-10', 265, 'ADD', '2017-02-10 12:18:01', '44.3126', 8000, '0.0000', 0),
(81, '2017-02-10', 266, 'ADD', '2017-02-10 12:19:31', '0.0000', 0, '44.3660', 9600),
(81, '2017-02-10', 267, 'ADD', '2017-02-10 12:19:51', '0.0000', 0, '44.3075', 6600),
(81, '2017-02-10', 268, 'ADD', '2017-02-10 12:32:05', '0.0000', 0, '44.2515', 8600),
(81, '2017-02-10', 269, 'ADD', '2017-02-10 12:47:43', '0.0000', 0, '44.2934', 2700),
(81, '2017-02-10', 270, 'ADD', '2017-02-10 12:49:49', '0.0000', 0, '44.4109', 2300),
(81, '2017-02-10', 271, 'ADD', '2017-02-10 12:56:24', '44.4600', 100, '0.0000', 0),
(81, '2017-02-10', 272, 'ADD', '2017-02-10 13:03:39', '0.0000', 0, '44.4000', 9000),
(81, '2017-02-10', 274, 'ADD', '2017-02-10 13:11:36', '44.4600', 3600, '0.0000', 0),
(81, '2017-02-10', 278, 'ADD', '2017-02-10 13:29:28', '0.0000', 0, '44.3612', 9400),
(81, '2017-02-10', 281, 'ADD', '2017-02-10 14:06:42', '44.4600', 4000, '0.0000', 0),
(81, '2017-02-10', 282, 'ADD', '2017-02-10 14:09:46', '0.0000', 0, '44.4011', 9600),
(81, '2017-02-10', 284, 'ADD', '2017-02-10 14:11:49', '44.4053', 5500, '0.0000', 0),
(81, '2017-02-10', 286, 'ADD', '2017-02-10 14:13:43', '44.4000', 4600, '0.0000', 0),
(81, '2017-02-10', 288, 'ADD', '2017-02-10 14:28:29', '0.0000', 0, '44.3552', 5100),
(81, '2017-02-10', 290, 'ADD', '2017-02-10 14:41:22', '0.0000', 0, '44.3976', 6300),
(81, '2017-02-10', 292, 'ADD', '2017-02-10 14:48:05', '0.0000', 0, '44.4210', 1700),
(81, '2017-02-10', 294, 'ADD', '2017-02-10 15:05:11', '0.0000', 0, '44.4678', 8800),
(81, '2017-02-10', 295, 'ADD', '2017-02-10 15:06:52', '44.3379', 3200, '0.0000', 0),
(81, '2017-02-10', 296, 'ADD', '2017-02-10 15:08:27', '44.4600', 7500, '0.0000', 0),
(81, '2017-02-10', 297, 'ADD', '2017-02-10 15:08:56', '0.0000', 0, '44.4600', 4700),
(81, '2017-02-10', 299, 'ADD', '2017-02-10 15:35:51', '44.4600', 7300, '0.0000', 0),
(81, '2017-02-10', 301, 'ADD', '2017-02-10 15:42:18', '0.0000', 0, '44.4261', 8300),
(81, '2017-02-10', 303, 'ADD', '2017-02-10 15:43:53', '44.4285', 2000, '0.0000', 0),
(81, '2017-02-10', 304, 'ADD', '2017-02-10 15:53:49', '0.0000', 0, '44.3491', 9500),
(81, '2017-02-10', 305, 'ADD', '2017-02-10 15:56:34', '0.0000', 0, '44.3400', 2400),
(81, '2017-02-10', 308, 'ADD', '2017-02-10 16:06:00', '44.3675', 2100, '0.0000', 0),
(81, '2017-02-10', 311, 'ADD', '2017-02-10 16:16:57', '44.3700', 300, '0.0000', 0),
(81, '2017-02-10', 313, 'ADD', '2017-02-10 16:27:50', '44.3192', 2300, '0.0000', 0),
(81, '2017-02-10', 315, 'ADD', '2017-02-10 16:32:34', '0.0000', 0, '44.2968', 2100),
(81, '2017-02-10', 319, 'ADD', '2017-02-10 16:38:30', '44.2833', 9500, '0.0000', 0),
(81, '2017-02-10', 320, 'ADD', '2017-02-10 16:57:37', '44.2178', 6300, '0.0000', 0),
(81, '2017-02-10', 321, 'ADD', '2017-02-10 16:57:39', '44.2811', 5100, '0.0000', 0),
(81, '2017-02-11', 323, 'ADD', '2017-02-11 09:03:26', '44.3100', 9700, '0.0000', 0),
(81, '2017-02-11', 324, 'ADD', '2017-02-11 09:05:30', '0.0000', 0, '44.2900', 6100),
(81, '2017-02-11', 325, 'ADD', '2017-02-11 09:08:17', '0.0000', 0, '44.3228', 8300),
(81, '2017-02-11', 328, 'ADD', '2017-02-11 09:44:43', '0.0000', 0, '44.2546', 6600),
(81, '2017-02-11', 330, 'ADD', '2017-02-11 09:49:25', '44.2456', 9200, '0.0000', 0),
(81, '2017-02-11', 334, 'ADD', '2017-02-11 10:09:52', '0.0000', 0, '44.3204', 5800),
(81, '2017-02-11', 339, 'ADD', '2017-02-11 10:38:28', '44.3954', 100, '0.0000', 0),
(81, '2017-02-11', 341, 'ADD', '2017-02-11 10:49:25', '0.0000', 0, '44.2456', 4600),
(81, '2017-02-11', 344, 'ADD', '2017-02-11 10:57:44', '0.0000', 0, '44.3494', 2400),
(81, '2017-02-11', 345, 'ADD', '2017-02-11 11:03:27', '44.3653', 400, '0.0000', 0),
(81, '2017-02-11', 346, 'ADD', '2017-02-11 11:06:12', '0.0000', 0, '44.4000', 1700),
(81, '2017-02-11', 347, 'ADD', '2017-02-11 11:07:34', '0.0000', 0, '44.3474', 2100),
(81, '2017-02-11', 350, 'ADD', '2017-02-11 11:23:43', '0.0000', 0, '44.3400', 3900),
(81, '2017-02-11', 351, 'ADD', '2017-02-11 11:24:01', '44.3360', 2800, '0.0000', 0),
(81, '2017-02-11', 352, 'ADD', '2017-02-11 11:24:13', '0.0000', 0, '44.2559', 9300),
(81, '2017-02-11', 353, 'ADD', '2017-02-11 11:24:31', '44.1888', 3400, '0.0000', 0),
(81, '2017-02-11', 354, 'ADD', '2017-02-11 11:25:31', '0.0000', 0, '44.3736', 3900),
(81, '2017-02-11', 355, 'ADD', '2017-02-11 11:33:49', '44.4295', 1100, '0.0000', 0),
(81, '2017-02-11', 356, 'ADD', '2017-02-11 11:36:36', '44.5000', 7100, '0.0000', 0),
(81, '2017-02-11', 357, 'ADD', '2017-02-11 11:38:38', '44.4643', 100, '0.0000', 0),
(81, '2017-02-11', 358, 'ADD', '2017-02-11 11:40:24', '44.4600', 3300, '0.0000', 0),
(81, '2017-02-11', 362, 'ADD', '2017-02-11 11:55:03', '44.4600', 7600, '0.0000', 0),
(81, '2017-02-11', 363, 'ADD', '2017-02-11 11:57:24', '44.4600', 100, '0.0000', 0),
(81, '2017-02-11', 364, 'ADD', '2017-02-11 12:01:59', '44.4215', 2500, '0.0000', 0),
(81, '2017-02-11', 367, 'ADD', '2017-02-11 12:15:29', '0.0000', 0, '44.4300', 2600),
(81, '2017-02-11', 371, 'ADD', '2017-02-11 12:44:19', '44.4300', 2600, '0.0000', 0),
(81, '2017-02-11', 372, 'ADD', '2017-02-11 12:51:26', '0.0000', 0, '44.4300', 2600),
(81, '2017-02-11', 376, 'ADD', '2017-02-11 13:08:14', '44.3763', 2100, '0.0000', 0),
(81, '2017-02-11', 377, 'ADD', '2017-02-11 13:11:24', '0.0000', 0, '44.4300', 9700),
(81, '2017-02-11', 380, 'ADD', '2017-02-11 13:31:43', '44.4273', 5900, '0.0000', 0),
(81, '2017-02-11', 382, 'ADD', '2017-02-11 13:44:28', '44.4600', 4000, '0.0000', 0),
(81, '2017-02-11', 383, 'ADD', '2017-02-11 13:48:34', '0.0000', 0, '44.4300', 3900),
(81, '2017-02-11', 386, 'ADD', '2017-02-11 13:58:03', '0.0000', 0, '44.4300', 2200),
(81, '2017-02-11', 387, 'ADD', '2017-02-11 14:00:46', '44.4020', 9600, '0.0000', 0),
(81, '2017-02-11', 388, 'ADD', '2017-02-11 14:03:07', '44.5000', 8900, '0.0000', 0),
(81, '2017-02-11', 389, 'ADD', '2017-02-11 14:03:52', '44.4566', 9900, '0.0000', 0),
(81, '2017-02-11', 390, 'ADD', '2017-02-11 14:09:18', '0.0000', 0, '44.3487', 8500),
(81, '2017-02-11', 394, 'ADD', '2017-02-11 14:20:34', '44.4022', 8200, '0.0000', 0),
(81, '2017-02-11', 397, 'ADD', '2017-02-11 14:38:47', '0.0000', 0, '44.4732', 6600),
(81, '2017-02-11', 399, 'ADD', '2017-02-11 14:48:21', '44.4511', 6600, '0.0000', 0),
(81, '2017-02-11', 400, 'ADD', '2017-02-11 15:04:54', '0.0000', 0, '44.5300', 5600),
(81, '2017-02-11', 403, 'ADD', '2017-02-11 15:07:18', '0.0000', 0, '44.5300', 4400),
(81, '2017-02-11', 404, 'ADD', '2017-02-11 15:16:17', '44.5734', 300, '0.0000', 0),
(81, '2017-02-11', 408, 'ADD', '2017-02-11 15:29:32', '44.5233', 2900, '0.0000', 0),
(81, '2017-02-11', 410, 'ADD', '2017-02-11 15:45:57', '0.0000', 0, '44.5014', 2400),
(81, '2017-02-11', 415, 'ADD', '2017-02-11 16:01:28', '0.0000', 0, '44.5319', 7100),
(81, '2017-02-11', 416, 'ADD', '2017-02-11 16:11:35', '0.0000', 0, '44.5436', 9800),
(81, '2017-02-11', 422, 'ADD', '2017-02-11 16:52:51', '0.0000', 0, '44.5010', 900),
(81, '2017-02-14', 425, 'ADD', '2017-02-14 09:23:16', '44.6200', 8900, '0.0000', 0),
(81, '2017-02-14', 435, 'ADD', '2017-02-14 09:58:49', '44.5957', 7600, '0.0000', 0),
(81, '2017-02-14', 439, 'ADD', '2017-02-14 10:13:04', '0.0000', 0, '44.5600', 7600),
(81, '2017-02-14', 444, 'ADD', '2017-02-14 10:28:13', '0.0000', 0, '44.4993', 700),
(81, '2017-02-14', 446, 'ADD', '2017-02-14 10:36:16', '44.6148', 8700, '0.0000', 0),
(81, '2017-02-14', 447, 'ADD', '2017-02-14 10:36:53', '0.0000', 0, '44.5835', 7400),
(81, '2017-02-14', 448, 'ADD', '2017-02-14 10:38:08', '0.0000', 0, '44.6500', 9100),
(81, '2017-02-14', 451, 'ADD', '2017-02-14 10:50:54', '0.0000', 0, '44.6500', 1700),
(81, '2017-02-14', 452, 'ADD', '2017-02-14 10:58:01', '0.0000', 0, '44.5638', 9500),
(81, '2017-02-14', 453, 'ADD', '2017-02-14 11:07:23', '44.7100', 8600, '0.0000', 0),
(81, '2017-02-14', 455, 'ADD', '2017-02-14 11:11:23', '44.6503', 2400, '0.0000', 0),
(81, '2017-02-14', 456, 'ADD', '2017-02-14 11:11:55', '44.7754', 4200, '0.0000', 0),
(81, '2017-02-14', 458, 'ADD', '2017-02-14 11:15:57', '44.6895', 7900, '0.0000', 0),
(81, '2017-02-14', 459, 'ADD', '2017-02-14 11:18:35', '0.0000', 0, '44.6678', 9000),
(81, '2017-02-14', 460, 'ADD', '2017-02-14 11:31:07', '0.0000', 0, '44.6135', 2300),
(81, '2017-02-14', 461, 'ADD', '2017-02-14 11:47:18', '0.0000', 0, '44.5521', 8700),
(81, '2017-02-14', 462, 'ADD', '2017-02-14 11:47:57', '0.0000', 0, '44.5600', 3100),
(81, '2017-02-14', 463, 'ADD', '2017-02-14 11:49:40', '0.0000', 0, '44.4979', 4600),
(81, '2017-02-14', 467, 'ADD', '2017-02-14 12:05:35', '44.6149', 9200, '0.0000', 0),
(81, '2017-02-14', 469, 'ADD', '2017-02-14 12:08:34', '0.0000', 0, '44.4586', 2000),
(81, '2017-02-14', 470, 'ADD', '2017-02-14 12:13:05', '44.3783', 5300, '0.0000', 0),
(81, '2017-02-14', 471, 'ADD', '2017-02-14 12:14:28', '0.0000', 0, '44.5600', 800),
(81, '2017-02-14', 472, 'ADD', '2017-02-14 12:16:53', '44.5637', 2700, '0.0000', 0),
(81, '2017-02-14', 477, 'ADD', '2017-02-14 12:31:50', '44.5575', 9100, '0.0000', 0),
(81, '2017-02-14', 479, 'ADD', '2017-02-14 12:36:42', '0.0000', 0, '44.5600', 3800),
(81, '2017-02-14', 482, 'ADD', '2017-02-14 12:54:33', '44.4749', 6500, '0.0000', 0),
(81, '2017-02-14', 483, 'ADD', '2017-02-14 12:56:49', '0.0000', 0, '44.5137', 7200),
(81, '2017-02-14', 484, 'ADD', '2017-02-14 12:58:52', '0.0000', 0, '44.5000', 9800),
(81, '2017-02-14', 486, 'ADD', '2017-02-14 12:59:48', '44.5837', 7900, '0.0000', 0),
(81, '2017-02-14', 487, 'ADD', '2017-02-14 13:11:59', '44.5505', 8200, '0.0000', 0),
(81, '2017-02-14', 490, 'ADD', '2017-02-14 13:14:39', '0.0000', 0, '44.4398', 9300),
(81, '2017-02-14', 491, 'ADD', '2017-02-14 13:20:59', '44.5210', 1400, '0.0000', 0);

--
-- Triggers `STOCK_QUOTE_FEED`
--
DELIMITER $$
CREATE TRIGGER `matchengine` AFTER INSERT ON `STOCK_QUOTE_FEED` FOR EACH ROW begin
  insert into STOCK_QUOTE_FEED2 values(NEW.INSTRUMENT_ID,NEW.QUOTE_DATE,NEW.QUOTE_SEQ_NBR,
  NEW.TRADING_SYMBOL,NEW.QUOTE_TIME,NEW.ASK_PRICE,NEW.ASK_SIZE,NEW.BID_PRICE,NEW.BID_SIZE);
  
if NEW.BID_PRICE > 0 then
    call matchbid(NEW.INSTRUMENT_ID,NEW.QUOTE_DATE,NEW.QUOTE_SEQ_NBR,
    NEW.TRADING_SYMBOL,NEW.QUOTE_TIME,NEW.ASK_PRICE,NEW.ASK_SIZE,NEW.BID_PRICE,NEW.BID_SIZE);
  else
  call matchask(NEW.INSTRUMENT_ID,NEW.QUOTE_DATE,NEW.QUOTE_SEQ_NBR,
  NEW.TRADING_SYMBOL,NEW.QUOTE_TIME,NEW.ASK_PRICE,NEW.ASK_SIZE,NEW.BID_PRICE,NEW.BID_SIZE);
end if;
end
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `STOCK_QUOTE_FEED2`
--

CREATE TABLE `STOCK_QUOTE_FEED2` (
  `INSTRUMENT_ID` int(11) NOT NULL,
  `QUOTE_DATE` date NOT NULL,
  `QUOTE_SEQ_NBR` int(11) NOT NULL,
  `TRADING_SYMBOL` varchar(15) DEFAULT NULL,
  `QUOTE_TIME` datetime DEFAULT NULL,
  `ASK_PRICE` decimal(18,4) DEFAULT NULL,
  `ASK_SIZE` int(11) DEFAULT NULL,
  `BID_PRICE` decimal(18,4) DEFAULT NULL,
  `BID_SIZE` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `STOCK_QUOTE_FEED2`
--

INSERT INTO `STOCK_QUOTE_FEED2` (`INSTRUMENT_ID`, `QUOTE_DATE`, `QUOTE_SEQ_NBR`, `TRADING_SYMBOL`, `QUOTE_TIME`, `ASK_PRICE`, `ASK_SIZE`, `BID_PRICE`, `BID_SIZE`) VALUES
(0, '2017-02-08', 8, 'AAA', '2017-02-08 09:40:49', '0.0000', 0, '21.9253', 4700),
(0, '2017-02-08', 9, 'AAA', '2017-02-08 09:41:57', '0.0000', 0, '21.9600', 7500),
(0, '2017-02-08', 15, 'AAA', '2017-02-08 10:03:05', '0.0000', 0, '21.9158', 7700),
(0, '2017-02-08', 16, 'AAA', '2017-02-08 10:09:12', '0.0000', 0, '21.8920', 8000),
(0, '2017-02-08', 20, 'AAA', '2017-02-08 10:29:06', '0.0000', 0, '21.9300', 5200),
(0, '2017-02-08', 21, 'AAA', '2017-02-08 10:31:59', '0.0000', 0, '21.8978', 8800),
(0, '2017-02-08', 34, 'AAA', '2017-02-08 11:03:10', '0.0000', 0, '21.9000', 9900),
(0, '2017-02-08', 35, 'AAA', '2017-02-08 11:03:20', '0.0000', 0, '21.8698', 2700),
(0, '2017-02-08', 38, 'AAA', '2017-02-08 11:13:45', '0.0000', 0, '21.9300', 7700),
(0, '2017-02-08', 41, 'AAA', '2017-02-08 11:26:10', '0.0000', 0, '21.9605', 500),
(0, '2017-02-08', 53, 'AAA', '2017-02-08 12:06:45', '22.0360', 9400, '0.0000', 0),
(0, '2017-02-08', 55, 'AAA', '2017-02-08 12:11:06', '22.0223', 5300, '0.0000', 0),
(0, '2017-02-08', 62, 'AAA', '2017-02-08 12:55:14', '22.1428', 7700, '0.0000', 0),
(0, '2017-02-08', 65, 'AAA', '2017-02-08 12:57:10', '22.0367', 1200, '0.0000', 0),
(0, '2017-02-08', 66, 'AAA', '2017-02-08 13:00:57', '22.1800', 7800, '0.0000', 0),
(0, '2017-02-08', 67, 'AAA', '2017-02-08 13:08:59', '22.1800', 6500, '0.0000', 0),
(0, '2017-02-08', 69, 'AAA', '2017-02-08 13:17:56', '22.1637', 4100, '0.0000', 0),
(0, '2017-02-08', 76, 'AAA', '2017-02-08 13:40:25', '22.1263', 3300, '0.0000', 0),
(0, '2017-02-08', 82, 'AAA', '2017-02-08 13:50:09', '22.1800', 2600, '0.0000', 0),
(0, '2017-02-08', 83, 'AAA', '2017-02-08 13:51:59', '22.1461', 400, '0.0000', 0),
(0, '2017-02-08', 85, 'AAA', '2017-02-08 13:56:02', '22.1119', 8300, '0.0000', 0),
(0, '2017-02-08', 113, 'AAA', '2017-02-08 15:37:02', '22.1200', 500, '0.0000', 0),
(0, '2017-02-08', 117, 'AAA', '2017-02-08 15:46:52', '22.0850', 7600, '0.0000', 0),
(0, '2017-02-08', 118, 'AAA', '2017-02-08 15:55:02', '22.0659', 5900, '0.0000', 0),
(0, '2017-02-08', 123, 'AAA', '2017-02-08 16:22:30', '22.0600', 9000, '0.0000', 0),
(0, '2017-02-08', 124, 'AAA', '2017-02-08 16:32:51', '22.0358', 7800, '0.0000', 0),
(0, '2017-02-08', 125, 'AAA', '2017-02-08 16:36:01', '0.0000', 0, '21.9312', 1400),
(0, '2017-02-08', 126, 'AAA', '2017-02-08 16:40:57', '22.0266', 7300, '0.0000', 0),
(0, '2017-02-08', 127, 'AAA', '2017-02-08 16:44:27', '0.0000', 0, '21.9082', 4000),
(0, '2017-02-09', 133, 'AAA', '2017-02-09 09:17:12', '0.0000', 0, '21.9329', 8800),
(0, '2017-02-09', 135, 'AAA', '2017-02-09 09:25:08', '0.0000', 0, '21.9609', 5400),
(0, '2017-02-09', 136, 'AAA', '2017-02-09 09:28:34', '0.0000', 0, '21.9935', 300),
(0, '2017-02-09', 140, 'AAA', '2017-02-09 09:46:35', '0.0000', 0, '21.9820', 8200),
(0, '2017-02-09', 148, 'AAA', '2017-02-09 10:19:01', '0.0000', 0, '21.9726', 7500),
(0, '2017-02-09', 150, 'AAA', '2017-02-09 10:20:06', '0.0000', 0, '21.9600', 2100),
(0, '2017-02-09', 152, 'AAA', '2017-02-09 10:26:36', '0.0000', 0, '21.9371', 6100),
(0, '2017-02-09', 155, 'AAA', '2017-02-09 10:41:35', '0.0000', 0, '21.8861', 9000),
(0, '2017-02-09', 180, 'AAA', '2017-02-09 12:17:47', '0.0000', 0, '21.7993', 3000),
(0, '2017-02-09', 183, 'AAA', '2017-02-09 12:40:55', '0.0000', 0, '21.8924', 1400),
(0, '2017-02-09', 193, 'AAA', '2017-02-09 13:16:23', '0.0000', 0, '21.8426', 4100),
(0, '2017-02-09', 195, 'AAA', '2017-02-09 13:24:26', '0.0000', 0, '21.8361', 2800),
(0, '2017-02-09', 196, 'AAA', '2017-02-09 13:36:43', '0.0000', 0, '21.8604', 5000),
(0, '2017-02-09', 197, 'AAA', '2017-02-09 13:40:00', '0.0000', 0, '21.9740', 9500),
(0, '2017-02-09', 205, 'AAA', '2017-02-09 14:03:55', '0.0000', 0, '21.8870', 4800),
(0, '2017-02-09', 209, 'AAA', '2017-02-09 14:13:49', '0.0000', 0, '21.8909', 4400),
(0, '2017-02-09', 210, 'AAA', '2017-02-09 14:18:55', '0.0000', 0, '21.9600', 3800),
(0, '2017-02-09', 211, 'AAA', '2017-02-09 14:19:54', '0.0000', 0, '21.9600', 600),
(0, '2017-02-09', 230, 'AAA', '2017-02-09 16:04:41', '0.0000', 0, '21.8615', 3400),
(0, '2017-02-10', 258, 'AAA', '2017-02-10 09:39:52', '22.0176', 8200, '0.0000', 0),
(0, '2017-02-10', 273, 'AAA', '2017-02-10 10:55:29', '22.0729', 8200, '0.0000', 0),
(0, '2017-02-10', 275, 'AAA', '2017-02-10 10:58:39', '0.0000', 0, '21.8711', 700),
(0, '2017-02-10', 276, 'AAA', '2017-02-10 11:04:04', '0.0000', 0, '21.9294', 6100),
(0, '2017-02-10', 278, 'AAA', '2017-02-10 11:12:00', '22.1490', 8900, '0.0000', 0),
(0, '2017-02-10', 280, 'AAA', '2017-02-10 11:16:06', '0.0000', 0, '21.9652', 7700),
(0, '2017-02-10', 285, 'AAA', '2017-02-10 11:43:25', '22.0869', 9800, '0.0000', 0),
(0, '2017-02-10', 286, 'AAA', '2017-02-10 11:44:35', '22.0600', 5300, '0.0000', 0),
(0, '2017-02-10', 288, 'AAA', '2017-02-10 11:59:55', '22.0873', 5800, '0.0000', 0),
(0, '2017-02-10', 292, 'AAA', '2017-02-10 12:18:32', '0.0000', 0, '21.9414', 700),
(0, '2017-02-10', 293, 'AAA', '2017-02-10 12:26:40', '0.0000', 0, '21.8767', 9400),
(0, '2017-02-10', 296, 'AAA', '2017-02-10 12:33:58', '0.0000', 0, '21.7800', 8700),
(0, '2017-02-10', 297, 'AAA', '2017-02-10 12:37:11', '0.0000', 0, '21.8044', 8700),
(0, '2017-02-10', 302, 'AAA', '2017-02-10 12:58:55', '0.0000', 0, '21.7500', 9600),
(0, '2017-02-10', 303, 'AAA', '2017-02-10 13:05:21', '0.0000', 0, '21.8358', 8100),
(0, '2017-02-10', 315, 'AAA', '2017-02-10 13:48:05', '0.0000', 0, '21.9092', 5200),
(0, '2017-02-10', 316, 'AAA', '2017-02-10 13:49:09', '0.0000', 0, '21.8671', 1000),
(0, '2017-02-10', 332, 'AAA', '2017-02-10 14:59:43', '0.0000', 0, '21.7800', 9300),
(0, '2017-02-11', 387, 'AAA', '2017-02-11 10:30:46', '22.0140', 6100, '0.0000', 0),
(0, '2017-02-11', 388, 'AAA', '2017-02-11 10:34:27', '22.0296', 6300, '0.0000', 0),
(0, '2017-02-11', 389, 'AAA', '2017-02-11 10:35:40', '0.0000', 0, '21.9518', 3500),
(0, '2017-02-11', 391, 'AAA', '2017-02-11 10:43:16', '22.0524', 1400, '0.0000', 0),
(0, '2017-02-11', 392, 'AAA', '2017-02-11 10:44:44', '0.0000', 0, '21.9600', 800),
(0, '2017-02-11', 394, 'AAA', '2017-02-11 11:02:34', '0.0000', 0, '21.9600', 8500),
(0, '2017-02-11', 397, 'AAA', '2017-02-11 11:25:46', '22.0957', 6700, '0.0000', 0),
(0, '2017-02-11', 401, 'AAA', '2017-02-11 12:00:38', '22.0843', 400, '0.0000', 0),
(0, '2017-02-11', 411, 'AAA', '2017-02-11 12:36:37', '22.2259', 6800, '0.0000', 0),
(0, '2017-02-11', 412, 'AAA', '2017-02-11 12:47:39', '22.0600', 6600, '0.0000', 0),
(0, '2017-02-11', 414, 'AAA', '2017-02-11 12:56:53', '22.0600', 5800, '0.0000', 0),
(0, '2017-02-11', 418, 'AAA', '2017-02-11 13:13:42', '22.0900', 1900, '0.0000', 0),
(0, '2017-02-11', 430, 'AAA', '2017-02-11 13:46:21', '0.0000', 0, '21.9600', 4800),
(0, '2017-02-11', 434, 'AAA', '2017-02-11 13:52:55', '0.0000', 0, '21.9998', 3800),
(0, '2017-02-11', 435, 'AAA', '2017-02-11 13:52:59', '22.0312', 6600, '0.0000', 0),
(0, '2017-02-11', 440, 'AAA', '2017-02-11 14:07:48', '0.0000', 0, '21.9597', 1900),
(0, '2017-02-11', 441, 'AAA', '2017-02-11 14:09:33', '22.1381', 1100, '0.0000', 0),
(0, '2017-02-11', 447, 'AAA', '2017-02-11 14:38:11', '0.0000', 0, '21.9322', 800),
(0, '2017-02-11', 462, 'AAA', '2017-02-11 15:37:38', '0.0000', 0, '21.8026', 300),
(0, '2017-02-11', 465, 'AAA', '2017-02-11 15:43:02', '0.0000', 0, '21.7911', 5900),
(0, '2017-02-11', 466, 'AAA', '2017-02-11 15:45:54', '0.0000', 0, '21.6800', 8400),
(0, '2017-02-11', 467, 'AAA', '2017-02-11 15:47:27', '0.0000', 0, '21.6800', 7700),
(0, '2017-02-11', 469, 'AAA', '2017-02-11 16:05:12', '22.1393', 9000, '0.0000', 0),
(0, '2017-02-11', 470, 'AAA', '2017-02-11 16:05:25', '0.0000', 0, '21.7683', 2500),
(0, '2017-02-11', 471, 'AAA', '2017-02-11 16:06:16', '0.0000', 0, '21.8198', 7200),
(0, '2017-02-11', 474, 'AAA', '2017-02-11 16:26:12', '0.0000', 0, '21.7500', 8400),
(0, '2017-02-11', 475, 'AAA', '2017-02-11 16:26:44', '0.0000', 0, '21.7500', 3900),
(27, '2017-02-08', 36, 'ABB', '2017-02-08 11:47:27', '0.0000', 0, '30.9472', 3700),
(27, '2017-02-08', 37, 'ABB', '2017-02-08 11:48:31', '0.0000', 0, '30.9600', 8900),
(27, '2017-02-08', 53, 'ABB', '2017-02-08 12:37:53', '0.0000', 0, '30.8130', 2500),
(27, '2017-02-08', 54, 'ABB', '2017-02-08 12:49:56', '0.0000', 0, '30.9600', 7800),
(27, '2017-02-08', 70, 'ABB', '2017-02-08 15:07:16', '0.0000', 0, '30.9609', 2800),
(27, '2017-02-08', 79, 'ABB', '2017-02-08 15:50:12', '0.0000', 0, '30.9048', 5600),
(27, '2017-02-08', 80, 'ABB', '2017-02-08 15:52:13', '0.0000', 0, '30.9427', 2000),
(27, '2017-02-08', 96, 'ABB', '2017-02-08 16:50:39', '0.0000', 0, '30.9373', 3200),
(27, '2017-02-08', 98, 'ABB', '2017-02-08 16:59:53', '0.0000', 0, '30.9967', 4200),
(27, '2017-02-09', 101, 'ABB', '2017-02-09 09:09:44', '0.0000', 0, '30.9799', 2200),
(27, '2017-02-09', 127, 'ABB', '2017-02-09 11:12:43', '0.0000', 0, '30.8834', 7000),
(27, '2017-02-09', 135, 'ABB', '2017-02-09 11:23:36', '0.0000', 0, '30.9841', 4400),
(27, '2017-02-09', 208, 'ABB', '2017-02-09 15:58:52', '0.0000', 0, '30.9642', 1300),
(27, '2017-02-10', 225, 'ABB', '2017-02-10 09:14:53', '0.0000', 0, '30.9871', 8600),
(27, '2017-02-10', 239, 'ABB', '2017-02-10 09:52:33', '0.0000', 0, '30.9341', 4000),
(27, '2017-02-10', 240, 'ABB', '2017-02-10 09:52:39', '0.0000', 0, '30.9996', 3600),
(27, '2017-02-10', 242, 'ABB', '2017-02-10 10:05:06', '0.0000', 0, '30.9829', 7300),
(27, '2017-02-10', 246, 'ABB', '2017-02-10 10:21:12', '0.0000', 0, '30.9939', 8400),
(27, '2017-02-11', 405, 'ABB', '2017-02-11 14:15:16', '31.4647', 2900, '0.0000', 0),
(27, '2017-02-11', 406, 'ABB', '2017-02-11 14:30:58', '31.5512', 4900, '0.0000', 0),
(27, '2017-02-11', 412, 'ABB', '2017-02-11 14:38:15', '31.5600', 5000, '0.0000', 0),
(27, '2017-02-11', 417, 'ABB', '2017-02-11 15:10:27', '31.5600', 3500, '0.0000', 0),
(27, '2017-02-11', 420, 'ABB', '2017-02-11 15:14:06', '31.5248', 3100, '0.0000', 0),
(27, '2017-02-11', 437, 'ABB', '2017-02-11 16:32:29', '31.5057', 8200, '0.0000', 0),
(27, '2017-02-14', 449, 'ABB', '2017-02-14 09:03:11', '31.5179', 7500, '0.0000', 0),
(27, '2017-02-14', 453, 'ABB', '2017-02-14 09:19:04', '31.5667', 6800, '0.0000', 0),
(27, '2017-02-14', 455, 'ABB', '2017-02-14 09:29:00', '31.5299', 8600, '0.0000', 0),
(27, '2017-02-14', 460, 'ABB', '2017-02-14 09:37:17', '31.5900', 6000, '0.0000', 0),
(27, '2017-02-14', 462, 'ABB', '2017-02-14 09:43:47', '31.5020', 3400, '0.0000', 0),
(27, '2017-02-14', 469, 'ABB', '2017-02-14 10:08:32', '31.4325', 3000, '0.0000', 0),
(27, '2017-02-14', 490, 'ABB', '2017-02-14 11:53:13', '31.5911', 1600, '0.0000', 0),
(27, '2017-02-14', 491, 'ABB', '2017-02-14 12:08:36', '31.5337', 4100, '0.0000', 0),
(54, '2017-02-08', 40, 'ACC', '2017-02-08 11:17:32', '0.0000', 0, '37.9600', 8900),
(54, '2017-02-11', 359, 'ACC', '2017-02-11 13:15:23', '0.0000', 0, '38.4976', 7100),
(54, '2017-02-11', 391, 'ACC', '2017-02-11 15:57:56', '0.0000', 0, '38.4600', 200),
(54, '2017-02-11', 395, 'ACC', '2017-02-11 16:01:40', '0.0000', 0, '38.4791', 6100),
(54, '2017-02-11', 397, 'ACC', '2017-02-11 16:03:41', '0.0000', 0, '38.4520', 4000),
(54, '2017-02-11', 398, 'ACC', '2017-02-11 16:05:28', '0.0000', 0, '38.4600', 8400),
(54, '2017-02-11', 401, 'ACC', '2017-02-11 16:15:54', '0.0000', 0, '38.4600', 9800),
(54, '2017-02-14', 418, 'ACC', '2017-02-14 10:06:32', '0.0000', 0, '38.4600', 2300),
(54, '2017-02-14', 419, 'ACC', '2017-02-14 10:07:30', '0.0000', 0, '38.4600', 5700),
(54, '2017-02-14', 422, 'ACC', '2017-02-14 10:20:48', '0.0000', 0, '38.4944', 6800),
(54, '2017-02-14', 475, 'ACC', '2017-02-14 14:12:54', '0.0000', 0, '38.7512', 3400),
(54, '2017-02-14', 491, 'ACC', '2017-02-14 14:59:24', '38.6755', 7500, '0.0000', 0),
(81, '2017-02-14', 462, 'ADD', '2017-02-14 11:47:57', '0.0000', 0, '44.5600', 3100),
(81, '2017-02-14', 463, 'ADD', '2017-02-14 11:49:40', '0.0000', 0, '44.4979', 4600),
(81, '2017-02-14', 469, 'ADD', '2017-02-14 12:08:34', '0.0000', 0, '44.4586', 2000),
(81, '2017-02-14', 483, 'ADD', '2017-02-14 12:56:49', '0.0000', 0, '44.5137', 7200),
(81, '2017-02-14', 484, 'ADD', '2017-02-14 12:58:52', '0.0000', 0, '44.5000', 9800),
(81, '2017-02-14', 486, 'ADD', '2017-02-14 12:59:48', '44.5837', 7900, '0.0000', 0),
(81, '2017-02-14', 487, 'ADD', '2017-02-14 13:11:59', '44.5505', 8200, '0.0000', 0),
(81, '2017-02-14', 490, 'ADD', '2017-02-14 13:14:39', '0.0000', 0, '44.4398', 9300),
(81, '2017-02-14', 491, 'ADD', '2017-02-14 13:20:59', '44.5210', 1400, '0.0000', 0);

-- --------------------------------------------------------

--
-- Table structure for table `STOCK_SLOPE`
--

CREATE TABLE `STOCK_SLOPE` (
  `INSTRUMENT_ID` int(11) NOT NULL,
  `TRADING_SYMBOL` varchar(15) DEFAULT NULL,
  `ASK_PRICE` decimal(18,4) DEFAULT 0.0000,
  `BID_PRICE` decimal(18,4) DEFAULT 0.0000,
  `SLOPE_BID` decimal(18,4) DEFAULT 1.0000,
  `SLOPE_ASK` decimal(18,4) DEFAULT 1.0000,
  `QUOTE_TIME_ASK` datetime DEFAULT NULL,
  `QUOTE_TIME_BID` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `STOCK_SLOPE`
--

INSERT INTO `STOCK_SLOPE` (`INSTRUMENT_ID`, `TRADING_SYMBOL`, `ASK_PRICE`, `BID_PRICE`, `SLOPE_BID`, `SLOPE_ASK`, `QUOTE_TIME_ASK`, `QUOTE_TIME_BID`) VALUES
(0, 'AAA', '21.7078', '21.8682', '-0.0001', '-0.0003', '2017-02-08 10:48:56', '2017-02-08 10:37:30'),
(27, 'ABB', '31.0221', '31.0684', '0.0002', '0.0000', '2017-02-08 10:32:10', '2017-02-08 10:56:44'),
(54, 'ACC', '38.0809', '38.1034', '0.0001', '-0.0002', '2017-02-08 10:24:52', '2017-02-08 10:18:39'),
(81, 'ADD', '44.0439', '44.0336', '0.0002', '0.0000', '2017-02-08 10:13:44', '2017-02-08 11:15:04');

-- --------------------------------------------------------

--
-- Table structure for table `STOCK_TRADE`
--

CREATE TABLE `STOCK_TRADE` (
  `INSTRUMENT_ID` int(11) NOT NULL,
  `TRADE_DATE` date NOT NULL,
  `TRADE_SEQ_NBR` int(11) NOT NULL,
  `TRADING_SYMBOL` varchar(15) DEFAULT NULL,
  `TRADE_TIME` datetime DEFAULT NULL,
  `TRADE_PRICE` decimal(18,4) DEFAULT NULL,
  `TRADE_SIZE` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `STOCK_QUOTE_FEED`
--
ALTER TABLE `STOCK_QUOTE_FEED`
  ADD PRIMARY KEY (`INSTRUMENT_ID`,`QUOTE_DATE`,`QUOTE_SEQ_NBR`),
  ADD KEY `XK2_STOCK_QUOTE` (`QUOTE_SEQ_NBR`),
  ADD KEY `XK4_STOCK_QUOTE` (`QUOTE_TIME`),
  ADD KEY `XK1_STOCK_QUOTE` (`QUOTE_DATE`),
  ADD KEY `XK3_STOCK_QUOTE` (`TRADING_SYMBOL`),
  ADD KEY `XK6_STOCK_QUOTE` (`ASK_PRICE`),
  ADD KEY `XK8_STOCK_QUOTE` (`ASK_SIZE`),
  ADD KEY `XK10_STOCK_QUOTE` (`BID_PRICE`),
  ADD KEY `XK12_STOCK_QUOTE` (`BID_SIZE`);

--
-- Indexes for table `STOCK_QUOTE_FEED2`
--
ALTER TABLE `STOCK_QUOTE_FEED2`
  ADD PRIMARY KEY (`INSTRUMENT_ID`,`QUOTE_DATE`,`QUOTE_SEQ_NBR`),
  ADD KEY `XK2_STOCK_QUOTE` (`QUOTE_SEQ_NBR`),
  ADD KEY `XK4_STOCK_QUOTE` (`QUOTE_TIME`),
  ADD KEY `XK1_STOCK_QUOTE` (`QUOTE_DATE`),
  ADD KEY `XK3_STOCK_QUOTE` (`TRADING_SYMBOL`),
  ADD KEY `XK6_STOCK_QUOTE` (`ASK_PRICE`),
  ADD KEY `XK8_STOCK_QUOTE` (`ASK_SIZE`),
  ADD KEY `XK10_STOCK_QUOTE` (`BID_PRICE`),
  ADD KEY `XK12_STOCK_QUOTE` (`BID_SIZE`);

--
-- Indexes for table `STOCK_SLOPE`
--
ALTER TABLE `STOCK_SLOPE`
  ADD PRIMARY KEY (`INSTRUMENT_ID`),
  ADD KEY `XK3_STOCK_QUOTE` (`TRADING_SYMBOL`),
  ADD KEY `XK6_STOCK_QUOTE` (`ASK_PRICE`),
  ADD KEY `XK10_STOCK_QUOTE` (`BID_PRICE`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
