// Copyright (C) 2021 - 2022 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Find the comma-separated strings to use in the legend
string[] set_legends(string runlegs)
{
   string[] legends;
   bool myleg = ((runlegs == "") ? false : true);
   bool flag = true;
   int n = -1;
   int lastpos = 0;
   string legends[];
   if(myleg) {
      string runleg;
      while(flag) {
	 ++n;
	 int pos = find(runlegs, ",", lastpos);
	 if(lastpos == -1) {
	   runleg = "";
	   flag = false;
	 }
    
	 runleg = substr(runlegs, lastpos, pos - lastpos);

	 lastpos = pos > 0 ? pos + 1 : -1;
	 if(flag)
	   legends.push(runleg);
      }
   }
   return legends;
}

// Create an array from a comma-separated string
string[] listfromcsv(string input)
{
    string list[] = new string[];
    int n = -1;
    bool flag = true;
    int lastpos;
    while(flag) {
        ++n;
        int pos = find(input, ",", lastpos);
        string found;
        if(lastpos == -1) {
            flag = false;
            found = "";
        }
        found = substr(input, lastpos, pos - lastpos);
        if(flag) {
            list.push(found);
            lastpos = pos > 0 ? pos + 1 : -1;
        }
    }
    return list;
}


struct datapoint
{
    string label;
  real[] length;
  string placeness;
    int ndev;
    real x;
    real y;
    real batch;
    real ylow;
    real yhigh;

    void operator init(real[] length,
                       real batch,
                       string placeness,
                       int ndev,
                       real y,
                       real ylow,
                       real yhigh) {
    this.length = length;
        this.x = length[0];
	this.batch = batch;
	this.placeness = placeness;
        this.ndev = ndev;
        this.y = y;
	this.ylow = ylow;
        this.yhigh = yhigh;
    }
  
  void mklabel(string ivariable) {
    
    if(ivariable == "lengths") {
      this.label = "$";
      this.label += (string)this.length[0];
      for(int i = 1; i < this.length.length; ++i) {
	this.label += "\times{}" + (string)this.length[i];
      }
      this.label += "$";
    }

    if(ivariable == "batch") {
      this.label = "$";
      this.label += (string)this.batch;
      this.label += "$";
      this.x = this.batch;
    }

    if(ivariable == "placeness") {
      this.label = this.placeness;
    }

    if(ivariable == "ndev") {
      this.label = "$";
      this.label += (string)this.ndev;
      this.label += "$";
      this.x = this.ndev;
    }

    
  }
}

// Read the data from the output files generated by alltime.py.
void readfiles(string[] filelist, datapoint[][] datapoints, bool pval = false)
{
    for(int n = 0; n < filelist.length; ++n)
    {
        string filename = filelist[n];
        //write("filename: ", filename);
        file fin = input(filename).line();
        
        string hdr = "";
        while(hdr == "")
        {
            hdr = fin;
        } 
        //write("header: ", hdr);
        
        bool moretoread = true;
        while(moretoread) {
	  string line = fin;

	  //write("line: ", line);

          // Separate the token from the data:
	  int pos = find(line, '\t', 0);
	  string token = substr(line, 0, pos);
	  //write("token: ", token);
	  string vals = substr(line, pos + 1, -1);
	  //write("vals: ", vals);

          // Parse the token:
          // Separate into individual words:
	  string[] words;
          bool flag = true;
	  int lastpos = 0;
	  while(flag) {
	    int pos = find(token, "_", lastpos);
	    if(lastpos == -1) {
	      flag = false;
	    }
	    if(flag) {
	      words.push(substr(token, lastpos, pos - lastpos));
	      lastpos = pos > 0 ? pos + 1 : -1;
	    }
	  }

	  //write(words);
	  
          // Grab the lengths:
          int lenidx = 3;
          real[] length = new real[];
          while(true) {
              real l = (real)words[lenidx];
              if(!initialized(l))
                  break;
              length.push(l);
              ++lenidx;
          }

	  real batch;
	  int batchidx = -1;
	  for(int idx = 0; idx < words.length; ++idx) {
	    if( words[idx] == 'batch') {
	      batchidx = idx + 1;
	      break;
	    }
	  }
	  if(batchidx != -1)  {
	    batch = (real)words[batchidx];
	  }

	  string placeness;
	  for(int idx = 0; idx < words.length; ++idx) {
	    if( words[idx] == 'ip' || words[idx] == 'op') {
	      placeness = words[idx];
	      break;
	    }
	  }
	  
          int ndev = 1;
          int devlist[] = {};
          for(int idx = 0; idx < words.length; ++idx) {
              if( words[idx] == 'dev') {
                  int devnum = (int)words[idx + 1];
                  bool newdev = true;
                  for(int jdx = 0; jdx < devlist.length; ++jdx) {
                      if(devnum == devlist[jdx]) {
                          newdev = false;
                          break;
                      }
                  }
                  if(newdev) {
                      devlist.push(devnum);
                  }
              }
          }
          ndev = max(ndev, devlist.length);
          //write(ndev, devlist.length);

	  //write("length: ", length);

          // Get the data:
	  lastpos = 0;
	  pos = find(vals, '\t', lastpos);
	  string smedian = substr(vals, lastpos, pos - lastpos);
	  //write("median: ", smedian);
	  lastpos = pos > 0 ? pos + 1 : -1;

          string slow, shigh;
          
          pos = find(vals, '\t', lastpos);
          slow = substr(vals, lastpos, pos - lastpos);
          //write("median low: ", slow);
          lastpos = pos > 0 ? pos + 1 : -1;
          
          pos = find(vals, '\t', lastpos);
          shigh = substr(vals, lastpos, pos - lastpos);
          //write("median high: ", shigh);
          lastpos = pos > 0 ? pos + 1 : -1;

                    
          datapoint d = datapoint(length,
                                  batch,
                                  placeness,
                                  ndev,
                                  (real)smedian,
                                  (real)slow,
                                  (real)shigh);

          pos = find(vals, '\t', lastpos);
          string spval = substr(vals, lastpos, pos - lastpos);
          //write("pval: ", spval);
          lastpos = pos > 0 ? pos + 1 : -1;
          
          d.x = length[0];

          //write(d.x);
          datapoints[n].push(d);
          
	  if(eof(fin)) {
	    moretoread = false;
	    break;
	  }
	    
        }
    }
}

void datapoints_to_xyvallowhigh(datapoint[] d,
                                pair[] xyval,
                                pair[] ylowhigh) {
    for(int i = 0; i < d.length; ++i) {
        xyval.push((d[i].x, d[i].y));
        ylowhigh.push((d[i].ylow, d[i].yhigh));
    }
}
    


// Given an array of values, get the x and y min and max.
real[] xyminmax( pair[][] xyval )
{
  // Find the bounds on the data to determine if the scales should be
  // logarithmic.
  real xmin = inf;
  real xmax = 0.0;
  real ymin = inf;
  real ymax = 0.0;
  for(int i = 0; i < xyval.length; ++i) {
    for(int j = 0; j < xyval[i].length; ++j) {
      xmax = max(xmax, xyval[i][j].x);
      ymax = max(ymax, xyval[i][j].y);
      xmin = min(xmin, xyval[i][j].x);
      ymin = min(ymin, xyval[i][j].y);
    }
  }
  real[] vals;
  vals.push(xmin);
  vals.push(xmax);
  vals.push(ymin);
  vals.push(ymax);
  return vals;
}
