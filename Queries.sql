CREATE DATABASE cs2; -- cs2 stands for case study 2
USE cs2;
CREATE TABLE sleepdaytable (id CHAR(10),
							sleepday CHAR(10),
                            totalsleeprecords INTEGER,
                            totalminutesasleep INTEGER,
							totaltimeinbed INTEGER);

CREATE TABLE cs2.caloriestable (	id CHAR(10),
									activityday CHAR(10),
									calories INTEGER);
                    
CREATE TABLE cs2.dailyactivity ( id CHAR(10),
							activitydate CHAR(30),
                            totalsteps INTEGER,
							totaldistance DOUBLE,
                            trackerdistance DOUBLE,
                            loggedactivitiesdistance DOUBLE,
                            veryactivedistance DOUBLE,
                            moderatelyactivedistance DOUBLE,
                            lightactivedistance DOUBLE,
                            sedentaryactivedistance DOUBLE,
                            veryactiveminutes INTEGER,
                            fairlyactiveminutes INTEGER,
                            lightlyactiveminutes INTEGER,
                            sedentaryminutes INTEGER,
                            calories INTEGER); 
                            
CREATE TABLE cs2.weight (	id CHAR(10),
							dates CHAR(10),
                            weightpounds DOUBLE,
                            weightkg DOUBLE,
                            bmi DOUBLE,
                            ismanualreport CHAR(5),
                            logid BIGINT);
                            						
/* converting the CVS date formats MM/DD/YYYY to SQL's date format YYYY/MM/DD*/
UPDATE cs2.sleepdaytable 
SET sleepday = date_format(sleepday, '%Y/%m/%d');
UPDATE cs2.dailyactivity 
SET activitydate = date_format(activitydate, '%Y/%m/%d');
UPDATE cs2.weight 
SET dates = date_format(dates, '%Y/%m/%d');
CREATE TABLE cs2.new_activity_day SELECT id, STR_TO_DATE(activityday, '%m/%d/%Y') AS activityday, calories FROM cs2.caloriestable;
-- I can't seems to Update the dates in the cs2.new_activity_day table. So I will replace the old one 
ALTER TABLE cs2.caloriestable RENAME cs2.temp;
DROP TABLE IF EXISTs cs2.temp;
ALTER TABLE cs2.new_activity_day RENAME cs2.caloriestable;
-- now the date is date is in ISO format YYYY/MM/DD

SELECT * FROM cs2.sleepdaytable;
SELECT * FROM cs2.dailyactivity;
SELECT * FROM cs2.weight;
SELECT * FROM cs2.caloriestable;
-- All the tables looks in order 

-- To begin with, let us see how many users are in each table 
SELECT COUNT(DISTINCT id) FROM cs2.caloriestable; -- 33 users
SELECT COUNT(DISTINCT id) FROM cs2.dailyactivity; -- 33 users
SELECT COUNT(DISTINCT id) FROM cs2.sleepdaytable; -- 24 users
SELECT COUNT(DISTINCT id) FROM cs2.weight; -- 8 users 

/* In excel, we checked for duplicated ID with the filter function and see that there are 33 IDs
We can go one step further and see if the IDs are duplicated on the same day */ 

SELECT id, activityday, COUNT(*) AS dup_row 
FROM cs2.caloriestable
GROUP BY id, activityday
HAVING dup_row > 1;
-- 0 dup_rows returned

SELECT id, activitydate, COUNT(*) AS dup_row
FROM cs2.dailyactivity
GROUP BY id, activitydate
HAVING dup_row >1;
-- 0 dup_rows returned

SELECT id, sleepday, COUNT(*) AS dup_row
FROM cs2.sleepdaytable
GROUP BY id, sleepday
HAVING dup_row >1;
/* 3 dup_rows returned, we will need to get rid of them with a DISTINCT 
we can do so by replacing the current table with a table that only has distinct values */

CREATE TABLE cs2.new_sleeptable SELECT DISTINCT * FROM cs2.sleepdaytable;

SELECT id, sleepday, COUNT(*) AS dup_row
FROM cs2.new_sleeptable
GROUP BY id, sleepday
HAVING dup_row >1;
-- 0 dup_rows returned, we can use this table to replace the old sleepdaytable

ALTER TABLE cs2.sleepdaytable RENAME cs2.old_table;
DROP TABLE IF EXISTS cs2.old_table;
ALTER TABLE cs2.new_sleeptable RENAME cs2.sleepdaytable;

SELECT id, dates, COUNT(*) AS dup_row
FROM cs2.weight 
GROUP BY id, dates
HAVING dup_row >1;
-- 0 dup_rows returned

/* Cleaning completed, queries starts */ 

/* Part 1 
The minutes of different activeness should be based upon the number of calories burned 
Let us first take a look at how well the minutes of activeness represents the user's exercising effort. 
We can do so by checking the correlation between active minutes and calories burned 
*/
   SELECT id, 
		  activitydate, 
          veryactiveminutes,  
          fairlyactiveminutes, 
          lightlyactiveminutes, 
          veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes AS total_active_minutes, 
          calories
   FROM cs2.dailyactivity
   GROUP BY id, activitydate;
-- there seems to be lack of a strong correlation between the duration of activeness and the amount of calories burnt 

-- this could be because people are already burning the amount of calories recorded through daily activities and not through exercise 
-- To prove this hypothesis, we can check to see how frequently people are burning the average daily calories 
SELECT COUNT(id)
FROM (
		SELECT id, COUNT(DISTINCT activityday) AS day_with_avg_calories
		FROM cs2.caloriestable
		WHERE calories BETWEEN 1600 AND 2200
		GROUP BY id
	 ) AS sub
WHERE sub.day_with_avg_calories >= 15;
-- Only 1 person burn the average calories everyday of the week and
-- 13 people burn the average calories at least half of the month 

-- We can also check how much people are burning above the max average daily calories
SELECT COUNT(id)
FROM (
		SELECT id, COUNT(DISTINCT activityday) AS day_with_above_avg_calories
		FROM cs2.caloriestable
		WHERE calories > 2200
		GROUP BY id
	 ) AS sub
WHERE sub.day_with_above_avg_calories > 15;
-- half of the users have burned more calories than when you are sedentary

-- Lastly, let's take a look at how many people burn less than the average 
SELECT COUNT(id)
FROM (
		SELECT id, COUNT(DISTINCT activityday) AS day_with_above_avg_calories
		FROM cs2.caloriestable
		WHERE calories < 2200
		GROUP BY id
	 ) AS sub
WHERE sub.day_with_above_avg_calories > 10;
-- Here, we see that more than half the users burn less than the average daily calories when you are sedentary 


/* Part 2
Base on the activeness of each user, Bellabeats can use reminders, rewards, and events to promote users 
that are below the average activeness of the user’s peers
Then, let us take a look at the number of different activeness minutes in comparison to sedentary minutes 
*/
SELECT 
	CONCAT(ROUND(SUM(veryactiveminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)*100), '%') AS Percentage_very,
    CONCAT(ROUND(SUM(fairlyactiveminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)*100), '%') AS Percentage_fairly,
    CONCAT(ROUND(SUM(lightlyactiveminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)*100), '%') AS Percentage_lightly,
    CONCAT(ROUND(SUM(sedentaryminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)*100), '%') AS Percentage_sedentary
FROM cs2.dailyactivity;
-- We can see that from all the users, 81% of all fitbit users are non-active 

--  When we have more data, it would be more precise to target marketing effort by looking at individual's behaviour
-- for example, we can provide different motivations or incentives base on user's own active to sedentary ratio 
SELECT
	id, 
	CONCAT(ROUND(SUM(veryactiveminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)*100), '%') AS Percentage_very,
    CONCAT(ROUND(SUM(fairlyactiveminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)*100), '%') AS Percentage_fairly,
    CONCAT(ROUND(SUM(lightlyactiveminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)*100), '%') AS Percentage_lightly,
    CONCAT(ROUND(SUM(sedentaryminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)*100), '%') AS Percentage_sedentary
FROM cs2.dailyactivity
GROUP BY id;

-- We can also allow the user to set their goals with the government recommended amount of exercise (30 mins a day for 5 days)
SELECT sub.id,
	   (AVG(sub.active_minutes) OVER(PARTITION BY sub.id))/20 AS avg_active_min,
       30 - (AVG(sub.active_minutes) OVER(PARTITION BY sub.id))/20 AS minutes_to_goal
   FROM (
   SELECT id,
		  veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes AS active_minutes
   FROM cs2.dailyactivity
   GROUP BY id
   ORDER BY active_minutes DESC
		) AS sub;

-- We can look at people that has average sedentary minutes, but also have the recommeded amount of active minutes everyday (30 mins)
-- Users in this category could be required to be sedentary (during work, school), but still make an effort to be active */
   SELECT id,
		  veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes AS active_minutes,
		  AVG(sedentaryminutes) OVER (PARTITION BY id) AS avg_sedentaryminutes
   FROM cs2.dailyactivity
   GROUP BY id
   ORDER BY active_minutes DESC 
   ;

-- We can also see if there is a certain day of the week where users is more or less active 
SELECT 
	day_of_week,
    AVG(totalsteps) AS avg_steps,
    AVG(totaldistance) AS avg_dis,
    AVG(calories) AS avg_cal
FROM (
		SELECT DAYNAME(activitydate) AS day_of_week,
        totalsteps,
        totaldistance,
        calories
        FROM cs2.dailyactivity
        ) AS sub
GROUP BY day_of_week;

-- let's take a look at how much the data differs
SELECT 
    sub.day_of_week,
    ROUND(MAX(sub.avg_steps) - MIN(sub.avg_steps), 2) AS steps_diff,
    ROUND(MAX(sub.avg_dis) - MIN(sub.avg_dis), 2) AS dis_diff,
    ROUND(MAX(sub.avg_cal) - MIN(sub.avg_cal), 2) AS cal_diff
FROM
    (SELECT 
			DAYNAME(activitydate) AS day_of_week,
            AVG(totalsteps) AS avg_steps,
            AVG(totaldistance) AS avg_dis,
            AVG(calories) AS avg_cal
	 FROM cs2.dailyactivity
     GROUP BY day_of_week) AS sub;
/* the current data shows that the biggest difference between the most active day 
   and the least active day is 156 calories. Which is around a tablespoon of olive oil */

/* Part 3
People with higher average active minutes to sedentary  minute ratio have shown weight loss  
In order to monitor changes in weight, we would need ids that recorded more than two times,
therefore, ids with only one entry should not be considered  
*/ 
SELECT *
FROM cs2.weight
WHERE id IN (
		SELECT id
		FROM cs2.weight 
		GROUP BY id
		HAVING COUNT(id) > 1);
-- Only 6 id has more than 1 entries 

-- Once we have found the ids with more than 1 entry, we can find out the weight net change of the record period with a simple window functions
 SELECT id, MIN(sub.percentage_weight_loss) AS net_weight_change
FROM 	(SELECT s.id, w.dates, MAX(w.logid), MIN(w.logid), w.weightpounds, 
			CONCAT(ROUND(((w.weightpounds - LAG(w.weightpounds) OVER (PARTITION BY id)) / w.weightpounds*100), 2), '%') AS percentage_weight_loss
		FROM cs2.weight AS w
		JOIN(	SELECT id
				FROM cs2.weight 
				GROUP BY id
				HAVING COUNT(id) > 1) AS s
			ON s.id = w.id
		GROUP BY w.logid) AS sub
GROUP BY sub.id;
-- of the 6 ids that recorded their weight, only 4 has lost weight compare to the first day

-- let's see the top six users and their active minutes
SELECT id, (1 - SUM(sedentaryminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)) AS percentage_active
FROM cs2.dailyactivity
GROUP BY id
ORDER BY percentage_active DESC
LIMIT 6;



-- let's see if the six users that recorded a weight lost is within the top six active users
SELECT b.id, a.net_weight_change
FROM (SELECT id, MIN(sub.percentage_weight_loss) AS net_weight_change
		FROM 	(SELECT s.id, w.dates, MAX(w.logid), MIN(w.logid), w.weightpounds, 
					CONCAT(ROUND(((w.weightpounds - LAG(w.weightpounds) OVER (PARTITION BY id)) / w.weightpounds*100), 2), '%') AS percentage_weight_loss
				FROM cs2.weight AS w
				JOIN(	SELECT id
						FROM cs2.weight 
						GROUP BY id
						HAVING COUNT(id) > 1) AS s
					ON s.id = w.id
				GROUP BY w.logid) AS sub
		GROUP BY sub.id) AS a
RIGHT JOIN
		(SELECT id, (1 - SUM(sedentaryminutes)/SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes)) AS percentage_active
		FROM cs2.dailyactivity
		GROUP BY id
		ORDER BY percentage_active DESC
		LIMIT 6) AS b
ON a.id = b.id; 
-- it turns out that of the six top users, one indeed have proven weight lost


/* Part 4
Next, let us look at how activeness affects sleep.
Is there a relationship between people who gets more sleep exercise more? 
*/
SELECT COUNT(DISTINCT id) FROM cs2.sleepdaytable;
SELECT COUNT(DISTINCT id) FROM cs2.dailyactivity;

-- using a left join here because we only want ids who have recored sleep and active level
SELECT a.id, a.sleepday, a.totalminutesasleep, b.active_minutes
FROM cs2.sleepdaytable AS a
LEFT JOIN (
			SELECT id, activitydate, SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes) AS active_minutes
			FROM cs2.dailyactivity
			GROUP BY id, activitydate
            ) AS b
	ON a.id = b.id
    AND a.sleepday = b.activitydate;
-- We can see that there is no strong relationship between minutes asleep and minutes being active

-- we can take a look at the average number per user, in case there are a few days where work occupied time for exercise 
SELECT 
	a.id,
    a.avg_sleep_minute,
    b.avg_active_minutes
FROM (
		SELECT id, AVG(totalminutesasleep) AS avg_sleep_minute
		FROM cs2.sleepdaytable
        GROUP BY id
        HAVING avg_sleep_minute > 68.50 
        )AS a
LEFT JOIN (
			SELECT id, AVG(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes) AS avg_active_minutes
			FROM cs2.dailyactivity
			GROUP BY id
            ) AS b
	ON a.id = b.id;
-- The result from the average set is consistent as the previous. There is no strong relationship indicated between minutes asleep and minutes active 
	

-- we can take a look whether being more active helps with falling asleep faster 
-- let's start by looking at relationship of individual kind of activities 
SELECT  a.id, a.sleepday, b.veryactiveminutes, b.fairlyactiveminutes, b.lightlyactiveminutes, b.sedentaryminutes, a.minutes_to_fall_asleep
FROM (	SELECT id, sleepday, totaltimeinbed - totalminutesasleep AS minutes_to_fall_asleep 
		FROM cs2.sleepdaytable
        GROUP BY id, minutes_to_fall_asleep) AS a
LEFT JOIN (	 SELECT id, activitydate, veryactiveminutes, fairlyactiveminutes, lightlyactiveminutes, sedentaryminutes
			 FROM cs2.dailyactivity
			 GROUP BY id, activitydate
		   ) AS b
	ON a.id = b.id
    AND a.sleepday = b.activitydate;


-- Then, let's see if there are any indications that people who are active in general fall asleep easier
SELECT  a.id, a.sleepday, a.minutes_to_fall_asleep, b.active_minutes
FROM (	SELECT id, sleepday, totaltimeinbed - totalminutesasleep AS minutes_to_fall_asleep 
		FROM cs2.sleepdaytable
        GROUP BY id, minutes_to_fall_asleep) AS a
LEFT JOIN (	 SELECT id, activitydate, SUM(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes) AS active_minutes
			 FROM cs2.dailyactivity
			 GROUP BY id, activitydate
		   ) AS b
	ON a.id = b.id
    AND a.sleepday = b.activitydate;
-- There is still no strong relationship indicating that being more active helps with falling asleep faster


   











