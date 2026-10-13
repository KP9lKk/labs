CREATE TABLE energy_type (
energy_type_id int PRIMARY KEY,
energy_type_name text NOT NULL,
energy_type_icon_url text NOT NULL 
)
 CREATE TABLE pokemon (
 pokemon_id int PRIMARY KEY,
 pokemon_name text NOT NULL,
 energy_type_id int REFERENCES energy_type(energy_type_id)

 )

