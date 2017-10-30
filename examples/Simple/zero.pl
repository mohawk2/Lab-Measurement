#-------- 0. Import Lab::Measurement -------

use Lab::Measurement;

#-------- 1. Initialize Instruments --------

my $gate_source = Instrument(
    'YokogawaGS200',
    {
        connection_type         => 'LinuxGPIB',
        gpib_address            => 1,
        gate_protect            => 0,
        gp_max_units            => 8,
        gp_min_units            => -8,
        gp_max_units_per_second => 0.03
    }
);

my $voltage_source = Instrument(
    'YokogawaGS200',
    {
        connection_type => 'LinuxGPIB',
        gpib_address    => 2,
        gate_protect    => 0,
    }
);

$gate_source->sweep_to_level( { target => 2.7 } );

