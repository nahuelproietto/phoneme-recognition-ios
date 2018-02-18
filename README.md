## Speech Recognition (Swift 3.0)
This is an open source implementation of MFCC feature extraction and DTW analysis. <br />
You will need to train the system before a test <br />
There is a level threashold of XdB in order to window the phoneme audio clip <br />
Frame default parameter for FFT are 1024 frames = 23ms +/- <br />
The system will extract 12 MFCC coefficients by default <br />
K-NN / DTW will compare it with the trained dataset. <br />
Once, you have enought data, you can tap on "Predict" and reproduce a phoneme <br />
## License
Some piece of software used on this repo are released under the MIT license. <br />
