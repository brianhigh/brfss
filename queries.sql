USE brfss;

SELECT IYEAR AS Year, COUNT(*) AS Respondents 
        FROM brfss 
        WHERE X_STATE = 53 
        GROUP BY IYEAR 
        ORDER BY IYEAR;

SELECT X_EDUCAG AS Education, COUNT(*) AS Respondents 
        FROM brfss 
        WHERE IYEAR = 2014 AND X_STATE = 53 
        GROUP BY X_EDUCAG 
        ORDER BY X_EDUCAG;

SELECT X_EDUCAG AS Education, 
        COUNT(USENOW3) AS Smokers 
        FROM brfss 
        WHERE IYEAR = 2014 AND X_STATE = 53 AND X_EDUCAG <= 4 
              AND (USENOW3 = 1 OR USENOW3 = 2) 
        GROUP BY X_EDUCAG 
        ORDER BY X_EDUCAG;

SELECT X_EDUCAG AS Education, 
        COUNT(*) AS Respondents, 
        COUNT(IF(USENOW3 = 1 OR USENOW3 = 2, 1, NULL)) AS Smokers 
        FROM brfss 
        WHERE IYEAR = 2014 AND X_STATE = 53 AND X_EDUCAG <= 4 
        GROUP BY X_EDUCAG 
        ORDER BY X_EDUCAG;

SELECT IYEAR AS Year, X_EDUCAG AS Education, 
        COUNT(*) AS Respondents, 
        COUNT(IF(USENOW3 = 1 OR USENOW3 = 2, 1, NULL)) AS Smokers
        FROM brfss 
        WHERE (IYEAR = 2011 OR IYEAR = 2012 OR IYEAR = 2013 OR IYEAR = 2014)
              AND X_STATE = 53 
              AND X_EDUCAG <= 4 
        GROUP BY IYEAR, X_EDUCAG 
        ORDER BY IYEAR, X_EDUCAG DESC;

SELECT X_EDUCAG AS Education, 
        COUNT(*) AS Respondents, 
        COUNT(IF(DRNKANY5 = 1, 1, NULL)) AS Drinkers 
        FROM brfss 
        WHERE IYEAR = 2014
              AND X_STATE = 53 
              AND X_EDUCAG <= 4 
        GROUP BY X_EDUCAG 
        ORDER BY X_EDUCAG DESC;

SELECT IYEAR AS Year, X_EDUCAG AS Education, 
        COUNT(*) AS Respondents, 
        COUNT(IF(DRNKANY5 = 1, 1, NULL)) AS Drinkers 
        FROM brfss 
        WHERE (IYEAR = 2011 OR IYEAR = 2012 OR IYEAR = 2013 OR IYEAR = 2014)
              AND X_STATE = 53 
              AND X_EDUCAG <= 4 
        GROUP BY IYEAR, X_EDUCAG 
        ORDER BY IYEAR, X_EDUCAG DESC;

SELECT IYEAR AS Year, X_EDUCAG AS Education, 
        COUNT(*) AS Respondents, 
        COUNT(IF(USENOW3 = 1 OR USENOW3 = 2, 1, NULL)) AS Smokers, 
        COUNT(IF(DRNKANY5 = 1, 1, NULL)) AS Drinkers 
        FROM brfss 
        WHERE (IYEAR = 2011 OR IYEAR = 2012 OR IYEAR = 2013 OR IYEAR = 2014)
              AND X_STATE = 53 
              AND X_EDUCAG <= 4 
        GROUP BY IYEAR, X_EDUCAG 
        ORDER BY IYEAR, X_EDUCAG;