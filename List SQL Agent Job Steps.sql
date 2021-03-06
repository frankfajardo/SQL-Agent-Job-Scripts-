use msdb

if object_id('tempdb..#mostRecentRunOfEachStep') is not null
	drop table #mostRecentRunOfEachStep

select * 
into #mostRecentRunOfEachStep
from sysjobhistory 
where step_id <> 0 
  and (convert(nvarchar(50), job_id) + ' ' + convert(nvarchar(50), step_id) + ' ' + convert(nvarchar(20), run_date) + ' ' + right('000000' + convert(nvarchar(6), run_time), 6)) in 
	(select convert(nvarchar(50), job_id) + ' ' + convert(nvarchar(50), step_id) + ' ' + max(convert(nvarchar(20), run_date) + ' ' + right('000000' + convert(nvarchar(6), run_time), 6))
	from sysjobhistory 
	where step_id <> 0 
	group by job_id, step_id)

select
	@@ServerName as 'Server'
	,jobs.name as 'Job Name'
	--,case when jobs.[enabled] = 1 then 'Yes' else 'No' end as 'Job Enabled'
	--,SUSER_SNAME(jobs.owner_sid) as 'Job Owner'
	--,categories.name as 'Job Category'
	--,jobs.description as 'Job Description'

	,steps.step_id as 'Step Number'
	,steps.step_name as 'Step Name'
	,steps.subsystem as 'Step Type'
	,case
		when proxies.name is null then ''
		else proxies.name
	 end as 'Run As'
	,case 
		when steps.database_name is null then ''
		else steps.database_name
	 end as 'Database'
	,steps.command as 'Command'

	,case steps.on_success_action
		when 1 then 'Quit the job reporting success'
		when 2 then 'Quit the job reporting failure'
		when 3 then 'Go to the next step'
		when 4 then 'Go to Step: ' 
					+ quoteName(cast(steps.on_success_step_id as varchar(3))) 
					+ ' ' 
					+ onSuccess.step_name
	 end as 'On Success'
	,steps.retry_attempts as 'Retry Attempts'
	,steps.retry_interval as 'Retry Interval (minutes)'
	,case steps.on_fail_action
		when 1 then 'Quit the job reporting success'
		when 2 then 'Quit the job reporting failure'
		when 3 then 'Go to the next step'
		when 4 then 'Go to Step: ' 
					+ quoteName(cast(steps.on_fail_step_id as varchar(3))) 
					+ ' ' 
					+ onFailure.step_name
	 end as 'On Failure'


	-- Add Last Run details
	,case 
		when steps.last_run_date = 0 then 'No info' 
		when steps.last_run_date is null then 'No info'
		else 
			stuff(stuff(cast(steps.last_run_date as char(8)), 5, 0, '/'), 8, 0, '/')
			+ ' ' 
			+ stuff(
				stuff(right('000000' + cast(steps.last_run_time as varchar(6)), 6)
					, 3, 0, ':')
				, 6, 0, ':')
	 end as 'Last Run Date/Time'
	,case 
		when (steps.last_run_date = 0 or steps.last_run_date is null) and steps.last_run_duration = 0 then ''
		else 
			stuff(
				stuff(right('000000' + cast(steps.last_run_duration as varchar(6)),  6)
					, 3, 0, ':')
				, 6, 0, ':')
	 end as 'Last Run Duration (hh:mm:ss)'
	,case
		when (steps.last_run_date = 0 or steps.last_run_date is null) and steps.last_run_outcome = 0 then ''
		when steps.last_run_outcome = 0 then 'Failed'
		when steps.last_run_outcome = 1 then 'Succeeded'
		when steps.last_run_outcome = 2 then 'Retry'
		when steps.last_run_outcome = 3 then 'Canceled'
		when steps.last_run_outcome = 5 then 'Unknown'
	 end as 'Last Run Status'
	--,steps.last_run_retries as 'Last Run Retries'
	,case 
		when jh.message is null then ''
		else jh.message 
	 end as 'Last Run Message'

from
	sysjobsteps as steps
	inner join sysjobs as jobs on steps.job_id = jobs.job_id
	left join sysjobsteps as onSuccess on steps.job_id = onSuccess.job_id and steps.on_success_step_id = onSuccess.step_id
	left join sysjobsteps as onFailure on steps.job_id = onFailure.job_id and steps.on_fail_step_id = onFailure.step_id
	left join sysproxies as proxies on steps.proxy_id = proxies.proxy_id
	left join syscategories as categories on categories.category_id = jobs.category_id
	left join #mostRecentRunOfEachStep as jh on jh.job_id = steps.job_id and jh.step_id = steps.step_id

order by jobs.name, steps.step_id
