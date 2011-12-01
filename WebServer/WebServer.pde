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
#include <EEPROM.h>
#include <SPI.h>
#include <Ethernet.h>
#include <LibHumidity.h>
//#include <LiquidCrystal.h>
#include <Wire.h>
#include <inttypes.h>
#include <LCDi2cW.h>
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
DeviceAddress insideThermometer2 = { 0x28, 0x7C, 0x76, 0x77, 0x03, 0x00, 0x00, 0xC0 };
DeviceAddress outsideThermometer = { 0x28, 0xED, 0x23, 0x77, 0x03, 0x00, 0x00, 0x01 };

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
                        
const int relayPin = 8; // Pin connected to relay.  Active LOW.  
const int fanPin = 7; // Pin connected to relay.  Active LOW.  
const int heatPin = 6; // Pin connected to relay.  Active LOW.  
const int coolPin = 5; // Pin connected to relay.  Active LOW.  

const int upButton = 9;     //Pin connected to UP button
const int downButton = 2;   //Pin connected to DOWN button 

int ledState = HIGH;
int upButtonState;
int lastUpButtonState = HIGH;
int downButtonState;
int lastDownButtonState = HIGH;

long lastDebounceTime = 0;
long debounceDelay = 100;
long deltaTime = 0;
long delayTime = 20000;
long deltaLCDTime = 0;
long delayLCDTime = 4000;
long deltaFanTime = 0;
long delayFanTime = 30000;

boolean fanDelayMet = false;
boolean fanON = false;
boolean heatON = false;
boolean coolON = false;

int externalTempDisplayCount = 1;

const int thermostatAddress = 10;
float tempSetPoint2 = EEPROM.read(thermostatAddress);

float temp1 = 70.0;        //Stores SHT21 temp to determine relay states
float tempE1 = 0.0;        //Stores External 1 Temp
float tempE2 = 0.0;        //Stores External 2 Temp
float tempE3 = 0.0;        //Stores External 3 Temp
float tempSetPoint = 65;  //Current Temp set point
float swing = 0.4;        //Sets swing control +/- tempSetPoint


//float tempC1, tempF1, tempC2, tempF2, humidity;
//int SDA = 4;      // Pin connected to SDA on SHT21
//int SCL = 5;      // Pin connected to SCL on SHT21

//Tested with SHT21 Breakout from Misenso
//SHT21 pin SDA to Arduino Analog pin 4
//SHT21 pin SCL to Arduino Analog pin 5
//SHT21 pin GND to Arduino GND
//SHT21 pin VCC to Arduion 3v (not 5v)
//LiquidCrystal_I2C lcd(0x27,20,4);  
LCDi2cW lcd = LCDi2cW(4,20,0x4C,0);

uint8_t rows = 2;
uint8_t cols = 20;

// Initialize the Ethernet server library
// with the IP address and port you want to use 
// (port 80 is default for HTTP):
Server server(5001);

void setup()
{
   deltaTime = millis(); 
   deltaLCDTime = millis(); 
   deltaFanTime = millis(); 
   lcd.init();
  
  lcd.print("INITIALIZING.. ");
  lcd.print(tempSetPoint);
  //delay(2000);
  //Wire.begin();
  // start the Ethernet connection and the server:
  pinMode(relayPin, OUTPUT);  //Set power Relay pin to output
  pinMode(fanPin, OUTPUT);    //Set FAN Relay pin to output
  pinMode(heatPin, OUTPUT);    //Set HEAT Relay pin to output
  pinMode(coolPin, OUTPUT);    //Set COOL Relay pin to output
  pinMode(upButton, INPUT);    //Set UP button pin to input
  pinMode(downButton, INPUT);  //Set DOWN button pin to input
  
  digitalWrite(fanPin, HIGH);   // set the Relay to NC
  digitalWrite(heatPin, HIGH);   // set the Relay to NC
  digitalWrite(coolPin, HIGH);   // set the Relay to NC
  digitalWrite(relayPin, HIGH);   // set the Relay to NC
  digitalWrite(upButton, HIGH);   // set the Relay to NC
  digitalWrite(downButton, HIGH);   // set the Relay to NC
  
  
   Serial.begin(9600);  //Start the serial connection with the copmuter
                       //to view the result open the serial monitor 
                       //last button beneath the file bar (looks like a box with an antenae)
  //I2C
  /*
  pinMode(16, OUTPUT);
  digitalWrite(16, LOW);  //GND pin
  pinMode(17, OUTPUT);
  digitalWrite(17, HIGH); //VCC pin      
  */
 
    // If you want to set the aref to something other than 5v
  analogReference(EXTERNAL);
    // Start up the library
  sensors.begin();
  // set the resolution to 10 bit (good enough?)
  sensors.setResolution(insideThermometer, 10);
  sensors.setResolution(insideThermometer2, 10);
  sensors.setResolution(outsideThermometer, 10);
  Ethernet.begin(mac, ip);
  server.begin();
  lcd.clear();
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
          //Pin 2 is Photo light sensor
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
           printClientTemperature(insideThermometer2, client);
           client.println("<br />");           //printing the result
           client.print("DS18B20+PAR# Outside Temp: ");
           printClientTemperature(outsideThermometer, client);
           client.println("<br />");           //printing the result
      /*    
          float temperature = getVoltage(temperaturePin);  //getting the voltage reading from the temperature sensor
 temperature = (((temperature - .5) * 100)*1.8)+32;          //converting from 10 mv per degree wit 500 mV offset
                                                  //to degrees ((volatge - 500mV) times 100)
     */                                             
          /* if (temperature <= 76.5) {
           digitalWrite(relayPin, LOW);    // set the Relay Low - Active LOW 
           }
           else
           digitalWrite(relayPin, HIGH);    // set the Relay Low - Active LOW 
           */
           /*
           client.print("TMP36 Temperature:      F: ");
           client.println(temperature);   
           client.println("<br />");           //printing the result
           */
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
 /*
 lcd.setCursor(0,0);
 lcd.print("Humidity: ");
 lcd.print(humidity.GetHumidity());
 lcd.setCursor(1,0);
 lcd.print("Temp  Inside: ");
 lcd.print(humidity.GetTemperatureF());
 lcd.setCursor(2,0);
 lcd.print("Temp Outside: ");
 lcd.print(DallasTemperature::toFahrenheit(tempC2));
 lcd.setCursor(3,0);
 lcd.print("T Set:");
 lcd.print(tempSetPoint);
 lcd.print(" Swing:");
 lcd.print(swing);
 */
 
 /*
 Serial.print("Humidity: ");
 Serial.println(humidity.GetHumidity());
 Serial.print("SHT21 Temp:          ");
 //Serial.println(humidity.GetTemperatureF());
 Serial.println(temp1);
 Serial.print("DS18B20+PAR #1 Temp: ");
 printTemperature(insideThermometer);
 Serial.print("\n\r");
 Serial.print("DS18B20+PAR# 2 Temp: ");
 printTemperature(insideThermometer2);
 Serial.print("\n\r");
 Serial.print("DS18B20+PAR# Outside Temp: ");
 printTemperature(outsideThermometer);
 Serial.print("\n\r");
 Serial.print("Relay Settings- Fan: ");
 Serial.print(digitalRead(fanPin));
 Serial.print(" Heat: ");
 Serial.print(digitalRead(heatPin));
 Serial.print(" Cool: ");
 Serial.println(digitalRead(coolPin));
 Serial.print("Temp Set Point: ");
 Serial.println(tempSetPoint);
 Serial.print("Temp Set Point in EEPROM: ");
 Serial.println(tempSetPoint2);
 */
  
 /*
    float temp1 = getVoltage(temperaturePin);  //getting the voltage reading from the temperature sensor
 temp1 = (((temp1 - .5) * 100)*1.8)+32;  
 */


 
 int readingUP = digitalRead(upButton);
 int readingDOWN = digitalRead(downButton);
 
 /*
 Serial.print("UP Button: ");
 Serial.print(digitalRead(upButton));
 Serial.print(" readingUP: ");
 Serial.print(readingUP);
 Serial.print(" lastUP: ");
 Serial.println(lastUpButtonState);
 Serial.print("DOWN Button: ");
 Serial.print(digitalRead(downButton));
 Serial.print(" readingDOWN: ");
 Serial.print(readingDOWN);
 Serial.print(" lastDOWN: ");
 Serial.println(lastDownButtonState); 
 Serial.print("\n\r");
 */
 
 if(readingUP != lastUpButtonState) {
  //reset the debounding timer
  //Serial.println("lastDebounceTime set");
   lastDebounceTime = millis(); 
 }
 if(readingDOWN != lastDownButtonState) {
  //reset the debounding timer
  // Serial.println("lastDebounceTime set");
   lastDebounceTime = millis(); 
 } 
 
 if ((millis() - lastDebounceTime) > debounceDelay) {
     //Serial.println("debounce Delay has been met");
    // whatever the reading is at, it's been there for longer
    // than the debounce delay, so take it as the actual current state:
    upButtonState = readingUP;
    downButtonState = readingDOWN;
    
      //Do stuff to set temp point
  if (upButtonState == LOW) {
    //Serial.println("UP button is low, increase tempSetPoint");
    tempSetPoint++;
     lcd.setCursor(3,0);
     lcd.print("Tset:");
     lcd.print(tempSetPoint);
    lastDebounceTime = millis(); 
  }
  if (downButtonState == LOW) {
    //Serial.println("Down button is low, reduce tempSetPoint");
    tempSetPoint--;
     lcd.setCursor(3,0);
     lcd.print("Tset:");
     lcd.print(tempSetPoint);
    lastDebounceTime = millis(); 
  }
    
   // Serial.print("upButtonState: ");
   // Serial.print(upButtonState);
   // Serial.print(" downButtonState: ");
   // Serial.println(downButtonState);
    
  } 
  /*
  //Do stuff to set temp point
  if (upButtonState == LOW) {
    //Serial.println("UP button is low, increase tempSetPoint");
    tempSetPoint++;
    lastDebounceTime = millis(); 
  }
  if (downButtonState == LOW) {
    //Serial.println("Down button is low, reduce tempSetPoint");
    tempSetPoint--;
    lastDebounceTime = millis(); 
  }
  */
  lastUpButtonState   = readingUP;
  lastDownButtonState = readingDOWN;
 
 //long clockPrevMillis = clockMillis;
 //long clockMillis = millis();
 //int millisSinceLastFrame = clockMillis - clockPrevMillis;

if ((millis() - deltaTime) > delayTime) { 
  //Print Serial data
  //Serial.println("PRINT SERIAL DATA");
  sensors.requestTemperatures();
  tempE1 = sensors.getTempC(insideThermometer);
  tempE2 = sensors.getTempC(insideThermometer2);  
  tempE3 = sensors.getTempC(outsideThermometer);
  temp1 = humidity.GetTemperatureF();
  if (tempSetPoint2 != tempSetPoint) {
    //Serial.println("SAVE tempSetPoint to EEPROM");
    EEPROM.write(thermostatAddress, tempSetPoint);
    tempSetPoint2 = EEPROM.read(thermostatAddress);
  }
 
 //Serial.print("Humidity: ");
 Serial.println(tempSetPoint);
 Serial.println(humidity.GetHumidity());
// Serial.print("SHT21 Temp:          ");
 //Serial.println(humidity.GetTemperatureF());
 Serial.println(temp1);
// Serial.print("DS18B20+PAR #1 Temp: ");
 printTemperature(insideThermometer);
 Serial.print("\n\r");
// Serial.print("DS18B20+PAR# 2 Temp: ");
 printTemperature(insideThermometer2);
 Serial.print("\n\r");
 //Serial.print("DS18B20+PAR# Outside Temp: ");
 printTemperature(outsideThermometer);
 Serial.print("\n\r");
  Serial.print("9999"); // Seperator for Processing to indicate last sensor in array has printed
  Serial.print("\n\r");
 //Serial.print("Relay Settings- Fan: ");
 //Serial.print(digitalRead(fanPin));
 //Serial.print(" Heat: ");
 //Serial.print(digitalRead(heatPin));
 //Serial.print(" Cool: ");
 //Serial.println(digitalRead(coolPin));
/*
 Serial.print("Temp Set Point: ");
 Serial.println(tempSetPoint);
 Serial.print("Temp Set Point in EEPROM: ");
 Serial.println(tempSetPoint2);
 Serial.print("\n\r");
 Serial.print("\n\r");
*/
 
 lcd.setCursor(0,0);
 lcd.print("Humidity: ");
 lcd.print(humidity.GetHumidity());
 lcd.setCursor(1,0);
 lcd.print("Temp  Inside: ");
 lcd.print(humidity.GetTemperatureF());
 //lcd.setCursor(2,0);
 //lcd.print("Temp Outside: ");
 //lcd.print(DallasTemperature::toFahrenheit(tempE3));
 lcd.setCursor(3,0);
 lcd.print("Tset:");
 lcd.print(tempSetPoint);
 lcd.print(" Sw:");
 lcd.print(swing);
 
  deltaTime = millis(); 
}

if ((millis() - deltaLCDTime) > delayLCDTime) {
  switch (externalTempDisplayCount) {
    case 1:
      //do something when var equals 1
       lcd.setCursor(2,0);
       lcd.print("Up Stairs:    ");
       lcd.print(DallasTemperature::toFahrenheit(tempE1));
      break;
    case 2:
      //do something when var equals 2
       lcd.setCursor(2,0);
       lcd.print("Bedroom:      ");
       lcd.print(DallasTemperature::toFahrenheit(tempE2));
      break;
    case 3:
      //do something when var equals 2
       lcd.setCursor(2,0);
       lcd.print("Outside Temp: ");
       lcd.print(DallasTemperature::toFahrenheit(tempE3));
       externalTempDisplayCount=0;
      break;  
    default: 
      // if nothing else matches, do the default
      // default is optional
      externalTempDisplayCount=0;
  } 
 externalTempDisplayCount++;
 deltaLCDTime = millis(); 
}  

// delay(1000);
 
 /*
 Serial.print("TMP36 Temp:          ");
 Serial.println(temp1);                     //printing the result
 */
             if (temp1 <= tempSetPoint - swing && heatON != true) {
               //digitalWrite(fanPin, LOW);    // set the Relay Low - Active LOW 
               deltaFanTime = millis();
               //if (fanDelayMet == true) {
               heatON = true;
               digitalWrite(heatPin, LOW);    // set the Relay Low - Active LOW 
               //}
               
           } else if (temp1 >= tempSetPoint + swing && heatON != false) {
           digitalWrite(heatPin, HIGH);    // set the Relay Low - Active LOW
           heatON = false;
            deltaFanTime = millis();
           //digitalWrite(fanPin, HIGH);    // set the Relay Low - Active LOW
           }
           
if ((millis() - deltaFanTime) > delayFanTime && heatON == true && fanON != true) {
           fanDelayMet = true;
           fanON = true;
           digitalWrite(fanPin, LOW);    // set the Relay Low - Active LOW 
           } 
          
if ((millis() - deltaFanTime) > delayFanTime && heatON == false && fanON != false) {
           fanDelayMet = true;
           fanON = false;
           digitalWrite(fanPin, HIGH);    // set the Relay Low - Active LOW 
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
    //Serial.print("C: ");
    //Serial.print(tempC);
    //Serial.print(" F: ");
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

