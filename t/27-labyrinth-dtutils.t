#!/usr/bin/perl -w
use strict;

use Test::More  tests => 15;
use Labyrinth::DTUtils;
use Labyrinth::Variables;
use Data::Dumper;

my %select = (
    'day1' => '<select id="day" name="day"><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="5">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option><option value="10">10</option><option value="11">11</option><option value="12">12</option><option value="13">13</option><option value="14">14</option><option value="15">15</option><option value="16">16</option><option value="17">17</option><option value="18">18</option><option value="19">19</option><option value="20">20</option><option value="21">21</option><option value="22">22</option><option value="23">23</option><option value="24">24</option><option value="25">25</option><option value="26">26</option><option value="27">27</option><option value="28">28</option><option value="29">29</option><option value="30">30</option><option value="31">31</option></select>',
    'day2' => '<select id="day" name="day"><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="5" selected="selected">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option><option value="10">10</option><option value="11">11</option><option value="12">12</option><option value="13">13</option><option value="14">14</option><option value="15">15</option><option value="16">16</option><option value="17">17</option><option value="18">18</option><option value="19">19</option><option value="20">20</option><option value="21">21</option><option value="22">22</option><option value="23">23</option><option value="24">24</option><option value="25">25</option><option value="26">26</option><option value="27">27</option><option value="28">28</option><option value="29">29</option><option value="30">30</option><option value="31">31</option></select>',
    'day3' => '<select id="day" name="day"><option value="0">Select Day</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="5" selected="selected">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option><option value="10">10</option><option value="11">11</option><option value="12">12</option><option value="13">13</option><option value="14">14</option><option value="15">15</option><option value="16">16</option><option value="17">17</option><option value="18">18</option><option value="19">19</option><option value="20">20</option><option value="21">21</option><option value="22">22</option><option value="23">23</option><option value="24">24</option><option value="25">25</option><option value="26">26</option><option value="27">27</option><option value="28">28</option><option value="29">29</option><option value="30">30</option><option value="31">31</option></select>',

    'month1' => '<select id="month" name="month"><option value="1">January</option><option value="2">February</option><option value="3">March</option><option value="4">April</option><option value="5">May</option><option value="6">June</option><option value="7">July</option><option value="8">August</option><option value="9">September</option><option value="10">October</option><option value="11">November</option><option value="12">December</option></select>',
    'month2' => '<select id="month" name="month"><option value="1">January</option><option value="2">February</option><option value="3">March</option><option value="4">April</option><option value="5" selected="selected">May</option><option value="6">June</option><option value="7">July</option><option value="8">August</option><option value="9">September</option><option value="10">October</option><option value="11">November</option><option value="12">December</option></select>',
    'month3' => '<select id="month" name="month"><option value="0">Select Month</option><option value="1">January</option><option value="2">February</option><option value="3">March</option><option value="4">April</option><option value="5" selected="selected">May</option><option value="6">June</option><option value="7">July</option><option value="8">August</option><option value="9">September</option><option value="10">October</option><option value="11">November</option><option value="12">December</option></select>',

    'year1' => '<select id="year" name="year"><option value="2014">2014</option><option value="2015">2015</option><option value="2016">2016</option><option value="2017">2017</option><option value="2018">2018</option></select>',
    'year3' => '<select id="year" name="year"><option value="2014">2014</option></select>',
    'year4' => '<select id="year" name="year"><option value="2014">2014</option><option value="2015">2015</option><option value="2016">2016</option><option value="2017">2017</option><option value="2018">2018</option></select>',
    'year5' => '<select id="year" name="year"><option value="2014">2014</option><option value="2015" selected="selected">2015</option><option value="2016">2016</option><option value="2017">2017</option><option value="2018">2018</option></select>',
    'year6' => '<select id="year" name="year"><option value="0">Select Year</option><option value="2014">2014</option><option value="2015" selected="selected">2015</option><option value="2016">2016</option><option value="2017">2017</option><option value="2018">2018</option></select>',
    'year7' => '<select id="year" name="year"><option value="0">Select Year</option><option value="2014">2014</option><option value="2015" selected="selected">2015</option><option value="2016">2016</option><option value="2017">2017</option><option value="2018">2018</option></select>',

    'period1' => '<select id="period" name="period"><option value="evnt-month">Month</option><option value="evnt-week">Week</option><option value="evnt-day">Day</option></select>',
    'period2' => '<select id="period" name="period"><option value="evnt-month">Month</option><option value="evnt-week">Week</option><option value="evnt-day">Day</option></select>',
    'period3' => '<select id="period" name="period"><option value="">Select Period</option><option value="evnt-month">Month</option><option value="evnt-week">Week</option><option value="evnt-day">Day</option></select>',
);

is(DaySelect(),   $select{day1},'DaySelect no options');
is(DaySelect(5),  $select{day2},'DaySelect with options');
is(DaySelect(5,1),$select{day3},'DaySelect with options and blank');

is(MonthSelect(),   $select{month1},'MonthSelect no options');
is(MonthSelect(5),  $select{month2},'MonthSelect with options');
is(MonthSelect(5,1),$select{month3},'MonthSelect with options and blank');

is(YearSelect(),        $select{year1},'YearSelect no options');
is(YearSelect(undef,2), $select{year3},'YearSelect range 2');
is(YearSelect(undef,3), $select{year4},'YearSelect range 3');
is(YearSelect(2015,3),  $select{year5},'YearSelect with options, range 3');
is(YearSelect(2015,3,1),$select{year6},'YearSelect with options, range 3 and blank');
is(YearSelect(2015,1,1,[2014,2015,2016,2017,2018]), $select{year7},'YearSelect with options, blank and date list');
    
is(PeriodSelect(),   $select{period1},'PeriodSelect no options');
is(PeriodSelect(5),  $select{period2},'PeriodSelect with options');
is(PeriodSelect(5,1),$select{period3},'PeriodSelect with options and blank');

# TODO:
# * OptSelect
# * formatDate
# * unformatDate
# * isMonth
# * _ext
