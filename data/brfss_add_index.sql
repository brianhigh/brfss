ALTER TABLE brfss ADD INDEX iyear_ndx (IYEAR);
ALTER TABLE brfss ADD INDEX iyear_x_state_ndx (IYEAR, X_STATE);
ALTER TABLE brfss ADD INDEX state_ndx (X_STATE);
