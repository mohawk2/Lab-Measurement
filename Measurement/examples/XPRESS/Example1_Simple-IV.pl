
#-------- 0. Create the hub ----------------

use Lab::XPRESS::hub;
my $hub = new Lab::XPRESS::hub();

#-------- 1. Initialize Instruments --------

my $voltage_source = $hub->Instrument('Yokogawa7651', 
	{
	connection_type => 'VISA_GPIB',
	gpib_address => 3,
	gate_protect => 0
	});

my $multimeter = $hub->Instrument('Agilent34410A', 
	{
	connection_type => 'VISA_GPIB',
	gpib_address => 17,
	nplc => 10					# integration time in number of powerline cylces [10*(1/50)]
	});

#-------- 3. Define the Sweeps -------------

my $voltage_sweep = $hub->Sweep('Voltage', 
	{
	instrument => $voltage_source,
	points => [-5e-3, 5e-3],	# [starting point, target] in Volts
	rate => [0.1, 0.5e-3],		# [rate to approach start, sweeping rate for measurement] in Volts/s
	interval => 1 				# measurement interval in s
	});

#-------- 3. Create a DataFile -------------

my $DataFile = $hub->DataFile('IVcurve_sample1.dat');

$DataFile->add_column('Voltage');
$DataFile->add_column('Current');
$DataFile->add_column('Resistance');


$DataFile->add_plot({
	'x-axis' => 'Voltage',
	'y-axis' => 'Current'
	}
	);

	
#-------- 4. Measurement Instructions -------

my $my_measurement = sub {

	my $sweep = shift;

	my $voltage = $voltage_source->get_value();
	my $current = $multimeter->get_value()*1e-7;
	my $resistance = ($current != 0) ? $voltage/$current : '?';

	$sweep->LOG({
		Voltage => $voltage,
		Current => $current,
		Resistance => $resistance
		});
};

#-------- 5. Put everything together -------

$DataFile->add_measurement($my_measurement);

$voltage_sweep->add_DataFile($DataFile);

$voltage_sweep->start();



1;

=pod

=encoding utf-8

=head1 Name

XPRESS for DUMMIES

=head1 Abstract

	This is a simple, but fully functional Lab::Measurment script, which makes use of the XPRESS add-on. 
	It's purpose as a measurement script is to record a single IV-curve. However it is also a step-by-step tutorial (for beginners) in writing a XPRESS-style Lab::Measurement script.
	
.

=head1 Introduction 

XPRESS is an add-on to Lab::Measurements, that serves several purposes: 
make writing scripts easy and structured, improve the script readability, save keystrokes and implement a whole bunch of features, that probably would make your scripts really messy if you would have to do it by your own.
In order to fulfill those goals, we chose a very modular approach, that enables you to interchange elements within a script, and by that creating a whole new measurement without writing everything from scratch.

There is a simple recipe for a XPRESS style measurment script:

	Ingredients:

	- Measurement instruments
	- Sweep Objects
	- A Datafile
	- Measurement instructions

	Throw everything together and start the script.

It's really that easy! In the following we would like to show you how to obtain the ingredients and how to put everything in place, using the example of a simple IV-curve measurement.

.

=head1 Step by step tutorial - How to write an IV-curve measurement

=head2 0. The hub
The hub is actually not an ingredient. In the metaphor of a recipe, the hub is rather the grocer, who supplies you with fresh ingredients. 
And every good chef needs his very own grocer, right? So let's see how to create a hub in your script:

	use Lab::XPRESS::hub;
	my $hub = new Lab::XPRESS::hub();

The first line is the PERL way to import a library. The second line, actually creates the hub as an object, and assigns this object to the variable $hub. 
Now, since we have the hub, it will be easy to obtain the rest.

=head2 1. Measurement instruments
For the measurment we need a voltage source and a multimeter to measure the current through our device. Physically the equipment is already next to the computer and connected via National Instruments GPIB interface.
But how do we get it into the script? Here is, how it's done for the voltage source (We chose a Yokogawa7651): 

	my $voltage_source = $hub->Instrument('Yokogawa7651', 
		{
		connection_type => 'VISA_GPIB',
		gpib_address => 5,
		gate_protect => 0
		});

As mentioned before, we receive the ingredients for our script (and therefore also instruments) from the hub. The function $hub->Instrument() returns the Instrument as a Lab::Measurement object, which we assign to the variable $voltage_source. As first parameter, we have to pass the name of the instrument. 
The second parameter, the part wrapped in {}, is the configuration hash. This hash should always contain at least the connection_type (here VISA_GPIB) and depending on the connection a corresponding address. Here we use, furthermore, the parameter gate_protect. Gate protection is a really great feature, which comes with Lab::Mesurement, that can help you protecting your samples. 
But since this is no gate, we don't want to use it now, we just turn it off by setting the parameter 0. The next example will introduce a gate, and explain the feature in more detail.
However the hash can contain more than that. The available options and parameters can be found in the particular instrument driver documentations. Let's try it on the example of our multimeter:

	my $multimeter = $hub->Instrument('Agilent34410A', 
		{
		connection_type => 'VISA_GPIB',
		gpib_address => 3,
		nplc => 10					# integration time in number of powerline cylces [10*(1/50)]
		});

In addition to the connection parameters, we specified the integration time of the multimeter, which will be set in the device automatically with the initialization, according to the given value.
Those are enough instruments for this simple experiment. Let's get the next ingrediant.

=head2 2. Sweep Objects

Sweeps are executable objects, which define the basic character of the experiment. Which variable is beeing changed during the experiment, and at which range? How fast is it changed? How often will the experiment be repeated?
To create a Sweep Object works very similar to initializing an instrument:

	my $voltage_sweep = $hub->Sweep('Voltage', 
		{
		instrument => $voltage_source,
		points => [-5e-3, 5e-3],	# [starting point, target] in Volts
		rate => [0.1, 0.5e-3],		# [rate to approach start, sweeping rate for measurement] in Volts/s
		interval => 1 				# measurement interval in s
		});

Again we have to specify the type of sweep ('Voltage' here) and a configuration hash. In the config hash we have to pass the Yokogawa as the conducting instrument of the sweep to the parameter instrument. 
The points parameter defines the starting point and the target of the Sweep in an array. 
In the rate array, the first value specifies the rate at which the starting point is approached, while the second value defines the rate at which the target will be approached.
Here points and rate are of length 2, but one could provide many more, in order to get a complex sweep sequence with changing sweep rates or reversing sweep directions. This is demonstrated in one of the other XPRESS example files.
Besides that, there are many other parameters and options available to characterise the sweep, which are documented under the perticular types of Sweep.

=head3 3. The DataFile

In order to log our measurements, we need a DataFile object. It can be obtaines using the hub:

	my $DataFile = $hub->DataFile('IVcurve_sample1.dat');

where we have to pass the desired filename as argument to the function $hub->DataFile(). Furthermore, columns have to be defined. For the purpose of the IV-curve, the following 3 are enough.

	$DataFile->add_column('Voltage');
	$DataFile->add_column('Current');
	$DataFile->add_column('Resistance');

The data will later be logged in the DataFile, corresponding to the order you added the columns. If you wish you can also add a plot to the DataFile, which will refresh live, each time a new data point is logged. In it's simplest form this can look like this:

	$DataFile->add_plot(
		{
		x-axis => 'Voltage',
		y-axis => 'Current'
		});

There are more parameters, that modify the look and type of the plot. Details can be found in the documentation of Lab::XPRESS::Data::XPRESS_DataFile.


=head2 4. The measurement instructions

As the last ingredient, we have to define how the data values per single measurement are generated. This set of instruction has to be wrapped into a subroutine, which will be executed each second while . First, let's have a look on the entire block, before discussing it in detail.

	my $my_measurement = sub {
	
		my $sweep = shift;
	
		my $voltage = $voltage_source->get_value();
		my $current = $multimeter->get_value()*1e-7;
		my $resistance = ($current != 0) ? $voltage/$current : '?';
	
		$sweep->LOG({
			Voltage => $voltage,
			Current => $current,
			Resistance => $resistance
			});
	};

Ok now have a closer look:

=over 4

=item * C< my $my_measurement = sub { ... > -- Here we indicate by the word 'sub', that a new subroutine is created, which instructions, are enclosed by {}. At the same time, the subroutine is assigned to the variable $my_measurement. This allows us to work with it later on.

=item * C< my $sweep = shift; > -- This line delivers us the current sweep object, which is important for propper logging of the data.

=item * C< my $voltage = $voltage_source->get_value(); > -- By using the function get_value() of the voltage_source we retrieve the currently applied voltage.

=item * C< my $current = $multimeter->get_value()*1e-7; > -- Same as before, however since we are using a current to voltage converter, we have to multiply the measured value with an amplification factor.

=item * C< my $resistance = ($current != 0) ? $voltage/$current : '?'; > -- This looks complicated, well but isn't. You have to read it like: If $current is not zero (?) then $resistance = $voltage / $current. Else (:) $resistance = '?'. This prevents from deviding by 0, which is not allowed. It might be unlikely, that $current is exactly 0, but we don't want to break our script in the middle of a measurement. 

=item * C< $sweep->LOG({
			Voltage => $voltage,
			Current => $current,
			Resistance => $resistance
			}); > 
		-- To store the generated values use $sweep->LOG(). With the hash you put into the function, you connect the freshly measured values with the columns you defined before in your DataFile.

=item * C< }; > -- close block and terminate with semicolon

=back

=head2 5. Putting everything in place

Now we have all ingredients together. But an onion and a potatoe lying side-by-side still make no dish. So, we have to put everything in place.
First, the DataFile has to know whats to do to generate a single line of data. That's why, we have to connect our created measurement subroutine with the DataFile:

	$DataFile->add_measurement($my_measurement);

But also, the Sweep has to know the DataFile:

	$voltage_sweep->add_DataFile($DataFile);

The internal process is the following: Every time a measurement should be performed (in our example every second, defined by the interval-parameter of the sweep), the sweep will call all of it's DataFiles (it can have several - i.e. if you have two or more samples -) and command them to log a new line of data. Therefore the DataFile will have to create the data first, using the instructions saved in $my_measurement.

Last but not least, the sweep has to be started:

	$voltage_sweep->start();

Otherwise the script won't do anything. 
And that's it!








=cut