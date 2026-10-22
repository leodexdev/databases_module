--Check in which medic_unit x staft will work
select staff.name, staff.surname, medic_unit.name from staff 
inner join shift on shift.staff_id = staff_id
inner join medic_unit on medic_unit.id = shift.medic_unit_id
where staff.name = 'x' and staff.surname = 'y';

--Check the name of the insurance that the patient use
select patient.name, patient.surname, insurance.name from patient
inner join report on report.patient_id = patient_id
inner join finance on finance.id = report.finance_id
inner join insurance_finance on insurance_finance.finance_id = ficance_id
inner join insurance on insurance.id = insurance_finance.insurance_id
where patient.name = "x" and patient.surname = "y";

--Check which staff has present in that episode
select staff.name, staff.surname, episode.id from staff
inner join staff_episode on staff_episode.staff_id = staff_id
inner join episode on episode.id = staff_episode.episode_id
where staff.name = "x" and staff.username = "y";

