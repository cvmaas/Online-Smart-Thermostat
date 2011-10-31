/*
 Thermostat Web  Server
 
 A simple web server that shows the value of the analog input pins.
 using an Arduino Wiznet Ethernet shield. 
 
 Circuit:
 * Ethernet shield attached to pins 10, 11, 12, 13
 * Analog inputs attached to pins A0 through A5 (optional)
 
 created 18 Dec 2009
 by David A. Mellis
 modified 4 Sep 2010
 by Tom Igoe
 
 */

#include <SPI.h>
#include <Ethernet.h>
#include <LibHumidity.h>
//#include <LiquidCrystal.h>
#include <Wire.h>
//#include <SHT2x.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#define aref_voltage 3.3         // we tie 3.3V to ARef and measure it with a multimeter!

// Data wire is plugged into pin 3 on the Arduino
#define ONE_WIRE_BUS 3

// Setup a oneWire instance to communicate with any OneWire devices
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&oneWire);

// Assign the addresses of your 1-Wire temp sensors.
// See the tutorial on how to obtain these addresses:
// http://www.hacktronics.com/Tutorials/arduino-1-wire-address-finder.html

DeviceAddress insideThermometer = { 0x28, 0x81, 0x12, 0x77, 0x03, 0x00, 0x00, 0xF6 };
DeviceAddress outsideThermometer = { 0x28, 0x7C, 0x76, 0x77, 0x03, 0x00, 0x00, 0xC0 };

LibHumidity humidity = LibHumidity(0);
//SHT2x sht2x = SHT2x();

// Enter a MAC address and IP address for your controller below.
// The IP address will be dependent on your local network:
byte mac[] = { 0x90, 0xA2, 0xDA, 0x00, 0x7C, 0x97 };
byte ip[] = { 192,168,1, 177 };

//TMP36 Pin Variables
int temperaturePin = 1; //the analog pin the TMP36's Vout (sense) pin is connected to
                        //the resolution is 10 mV / degree centigrade 
                        //(500 mV offset) to make negative temperatures an option
                        
int relayPin = 7; // Pin connected to relay.  Active LOW.  
//float tempC1, tempF1, tempC2, tempF2, humidity;
//int SDA = 4;      // Pin connected to SDA on SHT21
//int SCL = 5;      // Pin connected to SCL on SHT21

//Tested with SHT21 Breakout from Misenso
//SHT21 pin SDA to Arduino Analog pin 4
//SHT21 pin SCL to Arduino Analog pin 5
//SHT21 pin GND to Arduino GND
//SHT21 pin VCC to Arduion 3v (not 5v)

// Initialize the Ethernet server library
// with the IP address and port you want to use 
// (port 80 is default for HTTP):
Server server(5001);

void setup()
{
  Wire.begin();
  // start the Ethernet connection and the server:
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, HIGH);   // set the LED on
   Serial.begin(9600);  //Start the serial connection with the copmuter
                       //to view the result open the serial monitor 
                       //last button beneath the file bar (looks like a box with an antenae)
  //I2C
  pinMode(16, OUTPUT);
  digitalWrite(16, LOW);  //GND pin
  pinMode(17, OUTPUT);
  digitalWrite(17, HIGH); //VCC pin      
    // If you want to set the aref to something other than 5v
  analogReference(EXTERNAL);
    // Start up the library
  sensors.begin();
  // set the resolution to 10 bit (good enough?)
  sensors.setResolution(insideThermometer, 10);
  sensors.setResolution(outsideThermometer, 10);
  Ethernet.begin(mac, ip);
  server.begin();
}

void loop()
{
  // listen for incoming clients
  Client client = server.available();
  if (client) {
    // an http request ends with a blank line
    boolean currentLineIsBlank = true;
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        // if you've gotten to the end of the line (received a newline
        // character) and the line is blank, the http request has ended,
        // so you can send a reply
        if (c == '\n' && currentLineIsBlank) {
          // send a standard http response header
          client.println("HTTP/1.1 200 OK");
          client.println("Content-Type: text/html");
          client.println();
          client.println("Arduino WebServer: Analog Sensor Readings");
          client.println("<br />");
          client.println("<br />");
         
          // output the value of each analog input pin
          for (int analogChannel = 0; analogChannel < 4; analogChannel++) {
            client.print("analog input ");
            client.print(analogChannel);
            client.print(" is ");
            client.print(analogRead(analogChannel));
            client.println("<br />");           
          }
           client.println("<br />");
          
           client.print("SHT21 Humidity: ");
           client.println(humidity.GetHumidity());   
           client.print("%");
           client.println("<br />");           //printing the result
           client.println("<br />");           //printing the result
           client.print("SHT21 Temperature:     C: ");
           client.println(humidity.GetTemperatureC());   
           client.print(" F: ");
           client.println(humidity.GetTemperatureF());   
           client.println("<br />");           //printing the result
           
           sensors.requestTemperatures();
           client.print("DS18B20+PAR #1 Temp: ");
           printClientTemperature(insideThermometer, client);
           client.println("<br />");           //printing the result
           client.print("DS18B20+PAR# 2 Temp: ");
           printClientTemperature(outsideThermometer, client);
           client.println("<br />");           //printing the result
          
          float temperature = getVoltage(temperaturePin);  //getting the voltage reading from the temperature sensor
 temperature = (((temperature - .5) * 100)*1.8)+32;          //converting from 10 mv per degree wit 500 mV offset
                                                  //to degrees ((volatge - 500mV) times 100)
          /* if (temperature <= 76.5) {
           digitalWrite(relayPin, LOW);    // set the Relay Low - Active LOW 
           }
           else
           digitalWrite(relayPin, HIGH);    // set the Relay Low - Active LOW 
           */
           client.print("TMP36 Temperature:      F: ");
           client.println(temperature);   
           client.println("<br />");           //printing the result
          break;
        }
        if (c == '\n') {
          // you're starting a new line
          currentLineIsBlank = true;
        } 
        else if (c != '\r') {
          // you've gotten a character on the current line
          currentLineIsBlank = false;
        }
      }
    }
    // give the web browser time to receive the data
    delay(1);
    // close the connection:
    client.stop();
  }
  //getTemperature21();
 Serial.print(" Humidity: ");
 Serial.println(humidity.GetHumidity());
 Serial.print("\n\r");
 Serial.print("\n\r");
 Serial.print("SHT21 Temp:          ");
 Serial.println(humidity.GetTemperatureF());
    float temp1 = getVoltage(temperaturePin);  //getting the voltage reading from the temperature sensor
 temp1 = (((temp1 - .5) * 100)*1.8)+32;  
 
 sensors.requestTemperatures();
 Serial.print("DS18B20+PAR #1 Temp: ");
 printTemperature(insideThermometer);
 Serial.print("\n\r");
 Serial.print("DS18B20+PAR# 2 Temp: ");
 printTemperature(outsideThermometer);
 Serial.print("\n\r");
 delay(1000);
 Serial.print("TMP36 Temp:          ");
 Serial.println(temp1);                     //printing the result
             if (temp1 <= 78) {
           digitalWrite(relayPin, LOW);    // set the Relay Low - Active LOW 
           } else if (temp1 >= 84) {
           digitalWrite(relayPin, HIGH);    // set the Relay Low - Active LOW
           }
}

/*
 * getVoltage() - returns the voltage on the analog input defined by
 * pin
 */
float getVoltage(int pin){
 return ((analogRead(pin) -27)* .00322265625); //converting from a 0 to 1024 digital range
                                        // to 0 to 5 volts (each 1 reading equals ~ 5 millivolts
}

void printTemperature(DeviceAddress deviceAddress)
{
  float tempC = sensors.getTempC(deviceAddress);
  if (tempC == -127.00) {
    Serial.print("Error getting temperature");
  } else {
    Serial.print("C: ");
    Serial.print(tempC);
    Serial.print(" F: ");
    Serial.print(DallasTemperature::toFahrenheit(tempC));
  }
}

void printClientTemperature(DeviceAddress deviceAddress, Client client)
{
  
  float tempC = sensors.getTempC(deviceAddress);
  if (tempC == -127.00) {
    client.print("Error getting temperature");
  } else {
    client.print("C: ");
    client.print(tempC);
    client.print(" F: ");
    client.print(DallasTemperature::toFahrenheit(tempC));
  }
}

/*
//Get SHT21 Temp
void getTemperature21() {
  humidity = SHT2x.GetHumidity();
  tempC2 = SHT2x.GetTemperature();
  tempF2 = 1.8 * tempC2 + 32.0;
}
*/

