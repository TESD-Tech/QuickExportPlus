
WITH filters AS (

    SELECT TO_NUMBER(prefs.value) AS yearid

        , '2031204' AS test_student_number

    FROM prefs

    WHERE prefs.name = 'coursearchiveyear'

)



, student_attendance AS (

SELECT students.dcid

    , students.STUDENT_NUMBER

    , students.GRADE_LEVEL

        , cc.SCHOOLID

        , terms.id termid

        , calendar_day.DATE_VALUE

        , bell_schedule.name bell_schedule

        , period.ABBREVIATION period

        , attendance_code.ATT_CODE

        , bell_schedule_items.START_TIME

        , TO_CHAR(TRUNC(SYSDATE) + ( bell_schedule_items.START_TIME /86400), 'HH:MI:SS AM') period_start

        , TO_CHAR(TRUNC(SYSDATE) + ( bell_schedule_items.END_TIME /86400), 'HH:MI:SS AM') period_end

, TO_CHAR(TRUNC(SYSDATE) + ( 

        CASE WHEN bell_schedule_items.START_TIME > attendance_time.time_in THEN bell_schedule_items.START_TIME ELSE attendance_time.time_in END

        /86400), 'HH:MI:SS AM') butt_in_seat_start

        , TO_CHAR(TRUNC(SYSDATE) + ( 

        CASE WHEN bell_schedule_items.END_TIME < attendance_time.time_out THEN bell_schedule_items.END_TIME ELSE attendance_time.time_out END

        /86400), 'HH:MI:SS AM') butt_in_seat_end

       

        , (bell_schedule_items.END_TIME - bell_schedule_items.START_TIME ) / 60 period_attendance_minutes

        

        , COALESCE( (CASE WHEN bell_schedule_items.END_TIME < attendance_time.time_out THEN bell_schedule_items.END_TIME ELSE attendance_time.time_out END

            - CASE WHEN bell_schedule_items.START_TIME > attendance_time.time_in THEN bell_schedule_items.START_TIME ELSE attendance_time.time_in END

            ) / 60, 0 ) student_attendance_minutes

    FROM filters

        INNER JOIN students ON students.STUDENT_NUMBER = filters.test_student_number OR filters.test_student_number IS NULL

        INNER JOIN cc ON cc.STUDENTID = students.id

            AND cc.SECTIONID > 0

        INNER JOIN terms ON terms.id = cc.termid

            AND terms.SCHOOLID = cc.SCHOOLID

            AND terms.YEARID = filters.yearid

        INNER JOIN calendar_day ON calendar_day.SCHOOLID = terms.SCHOOLID

            AND calendar_day.DATE_VALUE BETWEEN terms.FIRSTDAY AND terms.LASTDAY

            AND calendar_day.DATE_VALUE <= TRIM(SYSDATE)

        INNER JOIN BELL_SCHEDULE ON BELL_SCHEDULE.ID = calendar_day.BELL_SCHEDULE_ID

        INNER JOIN bell_schedule_items ON BELL_SCHEDULE_items.BELL_SCHEDULE_ID = BELL_SCHEDULE.id

        INNER JOIN period ON period.id = bell_schedule_items.PERIOD_ID

        INNER JOIN cycle_day ON cycle_day.id = calendar_day.CYCLE_DAY_ID

        INNER JOIN section_meeting ON section_meeting.SECTIONID = cc.SECTIONID

            AND section_meeting.PERIOD_NUMBER = period.PERIOD_NUMBER

            AND section_meeting.CYCLE_DAY_LETTER = cycle_day.LETTER

            AND section_meeting.SCHOOLID = cc.SCHOOLID

            AND section_meeting.YEAR_ID = filters.yearid

        INNER JOIN attendance ON attendance.STUDENTID = students.id

            AND attendance.SCHOOLID = cc.SCHOOLID

            AND attendance.YEARID = filters.yearid

            AND attendance.ATT_DATE = calendar_day.DATE_VALUE

            AND attendance.ATT_MODE_CODE = 'ATT_ModeDaily'

        INNER JOIN attendance_code ON attendance_code.id = attendance.ATTENDANCE_CODEID

            AND ATTENDANCE_CODE.YEARID = filters.yearid

            AND attendance_code.SCHOOLID = cc.SCHOOLID

            AND attendance_code.ATT_CODE IN ('TUX', 'TUX-D')

        LEFT JOIN attendance_time ON attendance_time.ATTENDANCEID = attendance.id

            AND bell_schedule_items.START_TIME BETWEEN attendance_time.TIME_IN AND attendance_time.TIME_OUT

)



SELECT base.*

    , SUM(period_attendance_minutes) OVER (

        PARTITION BY dcid, DATE_VALUE 

        ORDER BY START_TIME

    ) as potential_instructional_minutes

    , SUM(student_attendance_minutes) OVER (

        PARTITION BY dcid, DATE_VALUE 

        ORDER BY START_TIME

    ) as actual_instructional_minutes

    

    ,

    SUM(period_attendance_minutes) OVER (

        PARTITION BY dcid

        ORDER BY DATE_VALUE, START_TIME

    )

    - SUM(student_attendance_minutes) OVER (

        PARTITION BY dcid

        ORDER BY DATE_VALUE, START_TIME

    ) 

    TUX_Minutes

, U_IS_AUTO_INST_MINUTES.REGULAR_CUTOFF_MINUTES


, FLOOR((SUM(period_attendance_minutes) OVER (

        PARTITION BY dcid

        ORDER BY DATE_VALUE, START_TIME

    )

    - SUM(student_attendance_minutes) OVER (

        PARTITION BY dcid

        ORDER BY DATE_VALUE, START_TIME

    )) / U_IS_AUTO_INST_MINUTES.REGULAR_CUTOFF_MINUTES)  TUX_D_Counter

FROM (

    SELECT *

FROM student_attendance

) base

INNER JOIN U_IS_AUTO_INST_MINUTES ON U_IS_AUTO_INST_MINUTES.label = CASE WHEN base.schoolid IN (3323, 3327) THEN 'M'

WHEN grade_level = 0 THEN 'K'

WHEN base.schoolid BETWEEN 4000 AND 5000 AND grade_level > 0 THEN 'E'

WHEN base.schoolid = 2080 THEN 'H'

ELSE '' END

ORDER BY dcid

,  DATE_VALUE DESC

    , START_TIME DESC
