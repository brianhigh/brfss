ALTER TABLE brfss ADD INDEX iyear_ndx (IYEAR);
ALTER TABLE brfss ADD INDEX iyear_x_state_ndx (IYEAR, X_STATE);
ALTER TABLE brfss ADD INDEX iyear_x_state_x_age80_ndx (IYEAR, X_STATE, X_AGE80);
ALTER TABLE brfss ADD INDEX iyear_x_age80_ndx (IYEAR, X_AGE80);
ALTER TABLE brfss ADD INDEX state_ndx (X_STATE);
