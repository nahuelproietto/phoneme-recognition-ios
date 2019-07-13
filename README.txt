Speech Recognition - Phoneme recognition.

This is an open source implementation of MFCC feature extraction and DTW analysis. 
You will need to train the system before. 
There is a level threashold of XdB in order to window the phoneme audio clip 
Frame default parameter for FFT are 1024 frames = 23ms +/- 
The system will extract 12 MFCC coefficients by default 
K-NN / DTW will compare it with the trained dataset. 
Once, you have enought data, you can tap on "Predict" and reproduce a phoneme 

Some piece of software used on this repo are released under the MIT license. 