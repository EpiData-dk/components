// +----------------------------------------------------------------------+
// |    chsdet - Charset Detector Library                                 |
// +----------------------------------------------------------------------+
// | Copyright (C) 2006, Nick Yakowlew     http://chsdet.sourceforge.net  |
// +----------------------------------------------------------------------+
// | Based on Mozilla sources     http://www.mozilla.org/projects/intl/   |
// +----------------------------------------------------------------------+
// | This library is free software; you can redistribute it and/or modify |
// | it under the terms of the GNU General Public License as published by |
// | the Free Software Foundation; either version 2 of the License, or    |
// | (at your option) any later version.                                  |
// | This library is distributed in the hope that it will be useful       |
// | but WITHOUT ANY WARRANTY; without even the implied warranty of       |
// | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                 |
// | See the GNU Lesser General Public License for more details.          |
// | http://www.opensource.org/licenses/lgpl-license.php                  |
// +----------------------------------------------------------------------+
//
// $Id: JpCntx.pas,v 1.2 2007/05/20 15:46:05 ya_nick Exp $

unit JpCntx;

interface
uses
	nsCore;

const
	NUM_OF_CATEGORY = 6;

type
	TJapaneseContextAnalysis = class (TObject)
		private
      (*category counters, each interger counts sequence in its category*)
      mRelSample: array [0..Pred(NUM_OF_CATEGORY)] of PRUint32;
      (*total sequence received*)
      mTotalRel: PRUint32;
      (*The order of previous char*)
      mLastCharOrder: integer;
      (*if last byte in current buffer is not the last byte of a character, we*)
      (*need to know how many byte to skip in next buffer.*)
      mNeedToSkipCharNum: integer;
      (*If this flag is set to PR_TRUE, detection is done and conclusion has been made*)
      mDone: Boolean;

 			function GetOrder(str: PChar;  charLen: pPRUint32): PRInt32; overload; virtual; abstract;
  		function GetOrder(str: PChar): PRInt32; overload; virtual; abstract;
		public
    	constructor Create;
      destructor Destroy; override;
			procedure Reset;
		  procedure HandleData(const aBuf: PChar;  aLen: integer);
		  procedure HandleOneChar(aStr: PChar;  aCharLen: integer);
			function GotEnoughData: Boolean;
			function GetConfidence: float;
	end;

  TSJISContextAnalysis = class (TJapaneseContextAnalysis)
    public
      function GetOrder(str: PChar;  charLen: pPRUint32): PRInt32; overload; override;
      function GetOrder(str: PChar): PRInt32; overload; override;
  end;
  
  TEUCJPContextAnalysis = class (TJapaneseContextAnalysis)
		public
      function GetOrder(str: PChar;  charLen: pPRUint32): PRInt32; overload; override;
      (*We only interested in Hiragana, so first byte is '\244'*)
      function GetOrder(str: PChar): PRInt32; overload; override;
	end;

implementation
const
	ENOUGH_REL_THRESHOLD = 100;
	MAX_REL_THRESHOLD = 1000;
	MINIMUM_DATA_THRESHOLD = 4;
	DONT_KNOW: float = -1;
  (*hiragana frequency category table*)
	//This is hiragana 2-char sequence table, the number in each cell represents its frequency category
	jp2CharContext: array [0..82, 0..82] of byte =
(
( 0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1),
( 2,4,0,4,0,3,0,4,0,3,4,4,4,2,4,3,3,4,3,2,3,3,4,2,3,3,3,2,4,1,4,3,3,1,5,4,3,4,3,4,3,5,3,0,3,5,4,2,0,3,1,0,3,3,0,3,3,0,1,1,0,4,3,0,3,3,0,4,0,2,0,3,5,5,5,5,4,0,4,1,0,3,4),
( 0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2),
( 0,4,0,5,0,5,0,4,0,4,5,4,4,3,5,3,5,1,5,3,4,3,4,4,3,4,3,3,4,3,5,4,4,3,5,5,3,5,5,5,3,5,5,3,4,5,5,3,1,3,2,0,3,4,0,4,2,0,4,2,1,5,3,2,3,5,0,4,0,2,0,5,4,4,5,4,5,0,4,0,0,4,4),
( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
( 0,3,0,4,0,3,0,3,0,4,5,4,3,3,3,3,4,3,5,4,4,3,5,4,4,3,4,3,4,4,4,4,5,3,4,4,3,4,5,5,4,5,5,1,4,5,4,3,0,3,3,1,3,3,0,4,4,0,3,3,1,5,3,3,3,5,0,4,0,3,0,4,4,3,4,3,3,0,4,1,1,3,4),
( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
( 0,4,0,3,0,3,0,4,0,3,4,4,3,2,2,1,2,1,3,1,3,3,3,3,3,4,3,1,3,3,5,3,3,0,4,3,0,5,4,3,3,5,4,4,3,4,4,5,0,1,2,0,1,2,0,2,2,0,1,0,0,5,2,2,1,4,0,3,0,1,0,4,4,3,5,4,3,0,2,1,0,4,3),
( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
( 0,3,0,5,0,4,0,2,1,4,4,2,4,1,4,2,4,2,4,3,3,3,4,3,3,3,3,1,4,2,3,3,3,1,4,4,1,1,1,4,3,3,2,0,2,4,3,2,0,3,3,0,3,1,1,0,0,0,3,3,0,4,2,2,3,4,0,4,0,3,0,4,4,5,3,4,4,0,3,0,0,1,4),
( 1,4,0,4,0,4,0,4,0,3,5,4,4,3,4,3,5,4,3,3,4,3,5,4,4,4,4,3,4,2,4,3,3,1,5,4,3,2,4,5,4,5,5,4,4,5,4,4,0,3,2,2,3,3,0,4,3,1,3,2,1,4,3,3,4,5,0,3,0,2,0,4,5,5,4,5,4,0,4,0,0,5,4),
( 0,5,0,5,0,4,0,3,0,4,4,3,4,3,3,3,4,0,4,4,4,3,4,3,4,3,3,1,4,2,4,3,4,0,5,4,1,4,5,4,4,5,3,2,4,3,4,3,2,4,1,3,3,3,2,3,2,0,4,3,3,4,3,3,3,4,0,4,0,3,0,4,5,4,4,4,3,0,4,1,0,1,3),
( 0,3,1,4,0,3,0,2,0,3,4,4,3,1,4,2,3,3,4,3,4,3,4,3,4,4,3,2,3,1,5,4,4,1,4,4,3,5,4,4,3,5,5,4,3,4,4,3,1,2,3,1,2,2,0,3,2,0,3,1,0,5,3,3,3,4,3,3,3,3,4,4,4,4,5,4,2,0,3,3,2,4,3),
( 0,2,0,3,0,1,0,1,0,0,3,2,0,0,2,0,1,0,2,1,3,3,3,1,2,3,1,0,1,0,4,2,1,1,3,3,0,4,3,3,1,4,3,3,0,3,3,2,0,0,0,0,1,0,0,2,0,0,0,0,0,4,1,0,2,3,2,2,2,1,3,3,3,4,4,3,2,0,3,1,0,3,3),
( 0,4,0,4,0,3,0,3,0,4,4,4,3,3,3,3,3,3,4,3,4,2,4,3,4,3,3,2,4,3,4,5,4,1,4,5,3,5,4,5,3,5,4,0,3,5,5,3,1,3,3,2,2,3,0,3,4,1,3,3,2,4,3,3,3,4,0,4,0,3,0,4,5,4,4,5,3,0,4,1,0,3,4),
( 0,2,0,3,0,3,0,0,0,2,2,2,1,0,1,0,0,0,3,0,3,0,3,0,1,3,1,0,3,1,3,3,3,1,3,3,3,0,1,3,1,3,4,0,0,3,1,1,0,3,2,0,0,0,0,1,3,0,1,0,0,3,3,2,0,3,0,0,0,0,0,3,4,3,4,3,3,0,3,0,0,2,3),
( 2,3,0,3,0,2,0,1,0,3,3,4,3,1,3,1,1,1,3,1,4,3,4,3,3,3,0,0,3,1,5,4,3,1,4,3,2,5,5,4,4,4,4,3,3,4,4,4,0,2,1,1,3,2,0,1,2,0,0,1,0,4,1,3,3,3,0,3,0,1,0,4,4,4,5,5,3,0,2,0,0,4,4),
( 0,2,0,1,0,3,1,3,0,2,3,3,3,0,3,1,0,0,3,0,3,2,3,1,3,2,1,1,0,0,4,2,1,0,2,3,1,4,3,2,0,4,4,3,1,3,1,3,0,1,0,0,1,0,0,0,1,0,0,0,0,4,1,1,1,2,0,3,0,0,0,3,4,2,4,3,2,0,1,0,0,3,3),
( 0,1,0,4,0,5,0,4,0,2,4,4,2,3,3,2,3,3,5,3,3,3,4,3,4,2,3,0,4,3,3,3,4,1,4,3,2,1,5,5,3,4,5,1,3,5,4,2,0,3,3,0,1,3,0,4,2,0,1,3,1,4,3,3,3,3,0,3,0,1,0,3,4,4,4,5,5,0,3,0,1,4,5),
( 0,2,0,3,0,3,0,0,0,2,3,1,3,0,4,0,1,1,3,0,3,4,3,2,3,1,0,3,3,2,3,1,3,0,2,3,0,2,1,4,1,2,2,0,0,3,3,0,0,2,0,0,0,1,0,0,0,0,2,2,0,3,2,1,3,3,0,2,0,2,0,0,3,3,1,2,4,0,3,0,2,2,3),
( 2,4,0,5,0,4,0,4,0,2,4,4,4,3,4,3,3,3,1,2,4,3,4,3,4,4,5,0,3,3,3,3,2,0,4,3,1,4,3,4,1,4,4,3,3,4,4,3,1,2,3,0,4,2,0,4,1,0,3,3,0,4,3,3,3,4,0,4,0,2,0,3,5,3,4,5,2,0,3,0,0,4,5),
( 0,3,0,4,0,1,0,1,0,1,3,2,2,1,3,0,3,0,2,0,2,0,3,0,2,0,0,0,1,0,1,1,0,0,3,1,0,0,0,4,0,3,1,0,2,1,3,0,0,0,0,0,0,3,0,0,0,0,0,0,0,4,2,2,3,1,0,3,0,0,0,1,4,4,4,3,0,0,4,0,0,1,4),
( 1,4,1,5,0,3,0,3,0,4,5,4,4,3,5,3,3,4,4,3,4,1,3,3,3,3,2,1,4,1,5,4,3,1,4,4,3,5,4,4,3,5,4,3,3,4,4,4,0,3,3,1,2,3,0,3,1,0,3,3,0,5,4,4,4,4,4,4,3,3,5,4,4,3,3,5,4,0,3,2,0,4,4),
( 0,2,0,3,0,1,0,0,0,1,3,3,3,2,4,1,3,0,3,1,3,0,2,2,1,1,0,0,2,0,4,3,1,0,4,3,0,4,4,4,1,4,3,1,1,3,3,1,0,2,0,0,1,3,0,0,0,0,2,0,0,4,3,2,4,3,5,4,3,3,3,4,3,3,4,3,3,0,2,1,0,3,3),
( 0,2,0,4,0,3,0,2,0,2,5,5,3,4,4,4,4,1,4,3,3,0,4,3,4,3,1,3,3,2,4,3,0,3,4,3,0,3,4,4,2,4,4,0,4,5,3,3,2,2,1,1,1,2,0,1,5,0,3,3,2,4,3,3,3,4,0,3,0,2,0,4,4,3,5,5,0,0,3,0,2,3,3),
( 0,3,0,4,0,3,0,1,0,3,4,3,3,1,3,3,3,0,3,1,3,0,4,3,3,1,1,0,3,0,3,3,0,0,4,4,0,1,5,4,3,3,5,0,3,3,4,3,0,2,0,1,1,1,0,1,3,0,1,2,1,3,3,2,3,3,0,3,0,1,0,1,3,3,4,4,1,0,1,2,2,1,3),
( 0,1,0,4,0,4,0,3,0,1,3,3,3,2,3,1,1,0,3,0,3,3,4,3,2,4,2,0,1,0,4,3,2,0,4,3,0,5,3,3,2,4,4,4,3,3,3,4,0,1,3,0,0,1,0,0,1,0,0,0,0,4,2,3,3,3,0,3,0,0,0,4,4,4,5,3,2,0,3,3,0,3,5),
( 0,2,0,3,0,0,0,3,0,1,3,0,2,0,0,0,1,0,3,1,1,3,3,0,0,3,0,0,3,0,2,3,1,0,3,1,0,3,3,2,0,4,2,2,0,2,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,2,1,2,0,1,0,1,0,0,0,1,3,1,2,0,0,0,1,0,0,1,4),
( 0,3,0,3,0,5,0,1,0,2,4,3,1,3,3,2,1,1,5,2,1,0,5,1,2,0,0,0,3,3,2,2,3,2,4,3,0,0,3,3,1,3,3,0,2,5,3,4,0,3,3,0,1,2,0,2,2,0,3,2,0,2,2,3,3,3,0,2,0,1,0,3,4,4,2,5,4,0,3,0,0,3,5),
( 0,3,0,3,0,3,0,1,0,3,3,3,3,0,3,0,2,0,2,1,1,0,2,0,1,0,0,0,2,1,0,0,1,0,3,2,0,0,3,3,1,2,3,1,0,3,3,0,0,1,0,0,0,0,0,2,0,0,0,0,0,2,3,1,2,3,0,3,0,1,0,3,2,1,0,4,3,0,1,1,0,3,3),
( 0,4,0,5,0,3,0,3,0,4,5,5,4,3,5,3,4,3,5,3,3,2,5,3,4,4,4,3,4,3,4,5,5,3,4,4,3,4,4,5,4,4,4,3,4,5,5,4,2,3,4,2,3,4,0,3,3,1,4,3,2,4,3,3,5,5,0,3,0,3,0,5,5,5,5,4,4,0,4,0,1,4,4),
( 0,4,0,4,0,3,0,3,0,3,5,4,4,2,3,2,5,1,3,2,5,1,4,2,3,2,3,3,4,3,3,3,3,2,5,4,1,3,3,5,3,4,4,0,4,4,3,1,1,3,1,0,2,3,0,2,3,0,3,0,0,4,3,1,3,4,0,3,0,2,0,4,4,4,3,4,5,0,4,0,0,3,4),
( 0,3,0,3,0,3,1,2,0,3,4,4,3,3,3,0,2,2,4,3,3,1,3,3,3,1,1,0,3,1,4,3,2,3,4,4,2,4,4,4,3,4,4,3,2,4,4,3,1,3,3,1,3,3,0,4,1,0,2,2,1,4,3,2,3,3,5,4,3,3,5,4,4,3,3,0,4,0,3,2,2,4,4),
( 0,2,0,1,0,0,0,0,0,1,2,1,3,0,0,0,0,0,2,0,1,2,1,0,0,1,0,0,0,0,3,0,0,1,0,1,1,3,1,0,0,0,1,1,0,1,1,0,0,0,0,0,2,0,0,0,0,0,0,0,0,1,1,2,2,0,3,4,0,0,0,1,1,0,0,1,0,0,0,0,0,1,1),
( 0,1,0,0,0,1,0,0,0,0,4,0,4,1,4,0,3,0,4,0,3,0,4,0,3,0,3,0,4,1,5,1,4,0,0,3,0,5,0,5,2,0,1,0,0,0,2,1,4,0,1,3,0,0,3,0,0,3,1,1,4,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0),
( 1,4,0,5,0,3,0,2,0,3,5,4,4,3,4,3,5,3,4,3,3,0,4,3,3,3,3,3,3,2,4,4,3,1,3,4,4,5,4,4,3,4,4,1,3,5,4,3,3,3,1,2,2,3,3,1,3,1,3,3,3,5,3,3,4,5,0,3,0,3,0,3,4,3,4,4,3,0,3,0,2,4,3),
( 0,1,0,4,0,0,0,0,0,1,4,0,4,1,4,2,4,0,3,0,1,0,1,0,0,0,0,0,2,0,3,1,1,1,0,3,0,0,0,1,2,1,0,0,1,1,1,1,0,1,0,0,0,1,0,0,3,0,0,0,0,3,2,0,2,2,0,1,0,0,0,2,3,2,3,3,0,0,0,0,2,1,0),
( 0,5,1,5,0,3,0,3,0,5,4,4,5,1,5,3,3,0,4,3,4,3,5,3,4,3,3,2,4,3,4,3,3,0,3,3,1,4,4,3,4,4,4,3,4,5,5,3,2,3,1,1,3,3,1,3,1,1,3,3,2,4,5,3,3,5,0,4,0,3,0,4,4,3,5,3,3,0,3,4,0,4,3),
( 0,5,0,5,0,3,0,2,0,4,4,3,5,2,4,3,3,3,4,4,4,3,5,3,5,3,3,1,4,0,4,3,3,0,3,3,0,4,4,4,4,5,4,3,3,5,5,3,2,3,1,2,3,2,0,1,0,0,3,2,2,4,4,3,1,5,0,4,0,3,0,4,3,1,3,2,1,0,3,3,0,3,3),
( 0,4,0,5,0,5,0,4,0,4,5,5,5,3,4,3,3,2,5,4,4,3,5,3,5,3,4,0,4,3,4,4,3,2,4,4,3,4,5,4,4,5,5,0,3,5,5,4,1,3,3,2,3,3,1,3,1,0,4,3,1,4,4,3,4,5,0,4,0,2,0,4,3,4,4,3,3,0,4,0,0,5,5),
( 0,4,0,4,0,5,0,1,1,3,3,4,4,3,4,1,3,0,5,1,3,0,3,1,3,1,1,0,3,0,3,3,4,0,4,3,0,4,4,4,3,4,4,0,3,5,4,1,0,3,0,0,2,3,0,3,1,0,3,1,0,3,2,1,3,5,0,3,0,1,0,3,2,3,3,4,4,0,2,2,0,4,4),
( 2,4,0,5,0,4,0,3,0,4,5,5,4,3,5,3,5,3,5,3,5,2,5,3,4,3,3,4,3,4,5,3,2,1,5,4,3,2,3,4,5,3,4,1,2,5,4,3,0,3,3,0,3,2,0,2,3,0,4,1,0,3,4,3,3,5,0,3,0,1,0,4,5,5,5,4,3,0,4,2,0,3,5),
( 0,5,0,4,0,4,0,2,0,5,4,3,4,3,4,3,3,3,4,3,4,2,5,3,5,3,4,1,4,3,4,4,4,0,3,5,0,4,4,4,4,5,3,1,3,4,5,3,3,3,3,3,3,3,0,2,2,0,3,3,2,4,3,3,3,5,3,4,1,3,3,5,3,2,0,0,0,0,4,3,1,3,3),
( 0,1,0,3,0,3,0,1,0,1,3,3,3,2,3,3,3,0,3,0,0,0,3,1,3,0,0,0,2,2,2,3,0,0,3,2,0,1,2,4,1,3,3,0,0,3,3,3,0,1,0,0,2,1,0,0,3,0,3,1,0,3,0,0,1,3,0,2,0,1,0,3,3,1,3,3,0,0,1,1,0,3,3),
( 0,2,0,3,0,2,1,4,0,2,2,3,1,1,3,1,1,0,2,0,3,1,2,3,1,3,0,0,1,0,4,3,2,3,3,3,1,4,2,3,3,3,3,1,0,3,1,4,0,1,1,0,1,2,0,1,1,0,1,1,0,3,1,3,2,2,0,1,0,0,0,2,3,3,3,1,0,0,0,0,0,2,3),
( 0,5,0,4,0,5,0,2,0,4,5,5,3,3,4,3,3,1,5,4,4,2,4,4,4,3,4,2,4,3,5,5,4,3,3,4,3,3,5,5,4,5,5,1,3,4,5,3,1,4,3,1,3,3,0,3,3,1,4,3,1,4,5,3,3,5,0,4,0,3,0,5,3,3,1,4,3,0,4,0,1,5,3),
( 0,5,0,5,0,4,0,2,0,4,4,3,4,3,3,3,3,3,5,4,4,4,4,4,4,5,3,3,5,2,4,4,4,3,4,4,3,3,4,4,5,5,3,3,4,3,4,3,3,4,3,3,3,3,1,2,2,1,4,3,3,5,4,4,3,4,0,4,0,3,0,4,4,4,4,4,1,0,4,2,0,2,4),
( 0,4,0,4,0,3,0,1,0,3,5,2,3,0,3,0,2,1,4,2,3,3,4,1,4,3,3,2,4,1,3,3,3,0,3,3,0,0,3,3,3,5,3,3,3,3,3,2,0,2,0,0,2,0,0,2,0,0,1,0,0,3,1,2,2,3,0,3,0,2,0,4,4,3,3,4,1,0,3,0,0,2,4),
( 0,0,0,4,0,0,0,0,0,0,1,0,1,0,2,0,0,0,0,0,1,0,2,0,1,0,0,0,0,0,3,1,3,0,3,2,0,0,0,1,0,3,2,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,4,0,2,0,0,0,0,0,0,2),
( 0,2,1,3,0,2,0,2,0,3,3,3,3,1,3,1,3,3,3,3,3,3,4,2,2,1,2,1,4,0,4,3,1,3,3,3,2,4,3,5,4,3,3,3,3,3,3,3,0,1,3,0,2,0,0,1,0,0,1,0,0,4,2,0,2,3,0,3,3,0,3,3,4,2,3,1,4,0,1,2,0,2,3),
( 0,3,0,3,0,1,0,3,0,2,3,3,3,0,3,1,2,0,3,3,2,3,3,2,3,2,3,1,3,0,4,3,2,0,3,3,1,4,3,3,2,3,4,3,1,3,3,1,1,0,1,1,0,1,0,1,0,1,0,0,0,4,1,1,0,3,0,3,1,0,2,3,3,3,3,3,1,0,0,2,0,3,3),
( 0,0,0,0,0,0,0,0,0,0,3,0,2,0,3,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,3,0,3,0,3,1,0,1,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,2,0,2,3,0,0,0,0,0,0,0,0,3),
( 0,2,0,3,1,3,0,3,0,2,3,3,3,1,3,1,3,1,3,1,3,3,3,1,3,0,2,3,1,1,4,3,3,2,3,3,1,2,2,4,1,3,3,0,1,4,2,3,0,1,3,0,3,0,0,1,3,0,2,0,0,3,3,2,1,3,0,3,0,2,0,3,4,4,4,3,1,0,3,0,0,3,3),
( 0,2,0,1,0,2,0,0,0,1,3,2,2,1,3,0,1,1,3,0,3,2,3,1,2,0,2,0,1,1,3,3,3,0,3,3,1,1,2,3,2,3,3,1,2,3,2,0,0,1,0,0,0,0,0,0,3,0,1,0,0,2,1,2,1,3,0,3,0,0,0,3,4,4,4,3,2,0,2,0,0,2,4),
( 0,0,0,1,0,1,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,2,2,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,3,1,0,0,0,0,0,0,0,3),
( 0,3,0,3,0,2,0,3,0,3,3,3,2,3,2,2,2,0,3,1,3,3,3,2,3,3,0,0,3,0,3,2,2,0,2,3,1,4,3,4,3,3,2,3,1,5,4,4,0,3,1,2,1,3,0,3,1,1,2,0,2,3,1,3,1,3,0,3,0,1,0,3,3,4,4,2,1,0,2,1,0,2,4),
( 0,1,0,3,0,1,0,2,0,1,4,2,5,1,4,0,2,0,2,1,3,1,4,0,2,1,0,0,2,1,4,1,1,0,3,3,0,5,1,3,2,3,3,1,0,3,2,3,0,1,0,0,0,0,0,0,1,0,0,0,0,4,0,1,0,3,0,2,0,1,0,3,3,3,4,3,3,0,0,0,0,2,3),
( 0,0,0,1,0,0,0,0,0,0,2,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1,0,0,1,0,0,0,0,0,3),
( 0,1,0,3,0,4,0,3,0,2,4,3,1,0,3,2,2,1,3,1,2,2,3,1,1,1,2,1,3,0,1,2,0,1,3,2,1,3,0,5,5,1,0,0,1,3,2,1,0,3,0,0,1,0,0,0,0,0,3,4,0,1,1,1,3,2,0,2,0,1,0,2,3,3,1,2,3,0,1,0,1,0,4),
( 0,0,0,1,0,3,0,3,0,2,2,1,0,0,4,0,3,0,3,1,3,0,3,0,3,0,1,0,3,0,3,1,3,0,3,3,0,0,1,2,1,1,1,0,1,2,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,2,2,1,2,0,0,2,0,0,0,0,2,3,3,3,3,0,0,0,0,1,4),
( 0,0,0,3,0,3,0,0,0,0,3,1,1,0,3,0,1,0,2,0,1,0,0,0,0,0,0,0,1,0,3,0,2,0,2,3,0,0,2,2,3,1,2,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,2,0,0,0,0,2,3),
( 2,4,0,5,0,5,0,4,0,3,4,3,3,3,4,3,3,3,4,3,4,4,5,4,5,5,5,2,3,0,5,5,4,1,5,4,3,1,5,4,3,4,4,3,3,4,3,3,0,3,2,0,2,3,0,3,0,0,3,3,0,5,3,2,3,3,0,3,0,3,0,3,4,5,4,5,3,0,4,3,0,3,4),
( 0,3,0,3,0,3,0,3,0,3,3,4,3,2,3,2,3,0,4,3,3,3,3,3,3,3,3,0,3,2,4,3,3,1,3,4,3,4,4,4,3,4,4,3,2,4,4,1,0,2,0,0,1,1,0,2,0,0,3,1,0,5,3,2,1,3,0,3,0,1,2,4,3,2,4,3,3,0,3,2,0,4,4),
( 0,3,0,3,0,1,0,0,0,1,4,3,3,2,3,1,3,1,4,2,3,2,4,2,3,4,3,0,2,2,3,3,3,0,3,3,3,0,3,4,1,3,3,0,3,4,3,3,0,1,1,0,1,0,0,0,4,0,3,0,0,3,1,2,1,3,0,4,0,1,0,4,3,3,4,3,3,0,2,0,0,3,3),
( 0,3,0,4,0,1,0,3,0,3,4,3,3,0,3,3,3,1,3,1,3,3,4,3,3,3,0,0,3,1,5,3,3,1,3,3,2,5,4,3,3,4,5,3,2,5,3,4,0,1,0,0,0,0,0,2,0,0,1,1,0,4,2,2,1,3,0,3,0,2,0,4,4,3,5,3,2,0,1,1,0,3,4),
( 0,5,0,4,0,5,0,2,0,4,4,3,3,2,3,3,3,1,4,3,4,1,5,3,4,3,4,0,4,2,4,3,4,1,5,4,0,4,4,4,4,5,4,1,3,5,4,2,1,4,1,1,3,2,0,3,1,0,3,2,1,4,3,3,3,4,0,4,0,3,0,4,4,4,3,3,3,0,4,2,0,3,4),
( 1,4,0,4,0,3,0,1,0,3,3,3,1,1,3,3,2,2,3,3,1,0,3,2,2,1,2,0,3,1,2,1,2,0,3,2,0,2,2,3,3,4,3,0,3,3,1,2,0,1,1,3,1,2,0,0,3,0,1,1,0,3,2,2,3,3,0,3,0,0,0,2,3,3,4,3,3,0,1,0,0,1,4),
( 0,4,0,4,0,4,0,0,0,3,4,4,3,1,4,2,3,2,3,3,3,1,4,3,4,0,3,0,4,2,3,3,2,2,5,4,2,1,3,4,3,4,3,1,3,3,4,2,0,2,1,0,3,3,0,0,2,0,3,1,0,4,4,3,4,3,0,4,0,1,0,2,4,4,4,4,4,0,3,2,0,3,3),
( 0,0,0,1,0,4,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,3,2,0,0,1,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,2),
( 0,2,0,3,0,4,0,4,0,1,3,3,3,0,4,0,2,1,2,1,1,1,2,0,3,1,1,0,1,0,3,1,0,0,3,3,2,0,1,1,0,0,0,0,0,1,0,2,0,2,2,0,3,1,0,0,1,0,1,1,0,1,2,0,3,0,0,0,0,1,0,0,3,3,4,3,1,0,1,0,3,0,2),
( 0,0,0,3,0,5,0,0,0,0,1,0,2,0,3,1,0,1,3,0,0,0,2,0,0,0,1,0,0,0,1,1,0,0,4,0,0,0,2,3,0,1,4,1,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,1,0,0,0,0,0,0,0,2,0,0,3,0,0,0,0,0,3),
( 0,2,0,5,0,5,0,1,0,2,4,3,3,2,5,1,3,2,3,3,3,0,4,1,2,0,3,0,4,0,2,2,1,1,5,3,0,0,1,4,2,3,2,0,3,3,3,2,0,2,4,1,1,2,0,1,1,0,3,1,0,1,3,1,2,3,0,2,0,0,0,1,3,5,4,4,4,0,3,0,0,1,3),
( 0,4,0,5,0,4,0,4,0,4,5,4,3,3,4,3,3,3,4,3,4,4,5,3,4,5,4,2,4,2,3,4,3,1,4,4,1,3,5,4,4,5,5,4,4,5,5,5,2,3,3,1,4,3,1,3,3,0,3,3,1,4,3,4,4,4,0,3,0,4,0,3,3,4,4,5,0,0,4,3,0,4,5),
( 0,4,0,4,0,3,0,3,0,3,4,4,4,3,3,2,4,3,4,3,4,3,5,3,4,3,2,1,4,2,4,4,3,1,3,4,2,4,5,5,3,4,5,4,1,5,4,3,0,3,2,2,3,2,1,3,1,0,3,3,3,5,3,3,3,5,4,4,2,3,3,4,3,3,3,2,1,0,3,2,1,4,3),
( 0,4,0,5,0,4,0,3,0,3,5,5,3,2,4,3,4,0,5,4,4,1,4,4,4,3,3,3,4,3,5,5,2,3,3,4,1,2,5,5,3,5,5,2,3,5,5,4,0,3,2,0,3,3,1,1,5,1,4,1,0,4,3,2,3,5,0,4,0,3,0,5,4,3,4,3,0,0,4,1,0,4,4),
( 1,3,0,4,0,2,0,2,0,2,5,5,3,3,3,3,3,0,4,2,3,4,4,4,3,4,0,0,3,4,5,4,3,3,3,3,2,5,5,4,5,5,5,4,3,5,5,5,1,3,1,0,1,0,0,3,2,0,4,2,0,5,2,3,2,4,1,3,0,3,0,4,5,4,5,4,3,0,4,2,0,5,4),
( 0,3,0,4,0,5,0,3,0,3,4,4,3,2,3,2,3,3,3,3,3,2,4,3,3,2,2,0,3,3,3,3,3,1,3,3,3,0,4,4,3,4,4,1,1,4,4,2,0,3,1,0,1,1,0,4,1,0,2,3,1,3,3,1,3,4,0,3,0,1,0,3,1,3,0,0,1,0,2,0,0,4,4),
( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
( 0,3,0,3,0,2,0,3,0,1,5,4,3,3,3,1,4,2,1,2,3,4,4,2,4,4,5,0,3,1,4,3,4,0,4,3,3,3,2,3,2,5,3,4,3,2,2,3,0,0,3,0,2,1,0,1,2,0,0,0,0,2,1,1,3,1,0,2,0,4,0,3,4,4,4,5,2,0,2,0,0,1,3),
( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,1,1,0,0,1,1,0,0,0,4,2,1,1,0,1,0,3,2,0,0,3,1,1,1,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,1,0,0,0,2,0,0,0,1,4,0,4,2,1,0,0,0,0,0,1),
( 0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,1,0,0,0,0,0,0,1,0,1,0,0,0,0,3,1,0,0,0,2,0,2,1,0,0,1,2,1,0,1,1,0,0,3,0,0,0,0,0,0,0,0,0,0,0,1,3,1,0,0,0,0,0,1,0,0,2,1,0,0,0,0,0,0,0,0,2),
( 0,4,0,4,0,4,0,3,0,4,4,3,4,2,4,3,2,0,4,4,4,3,5,3,5,3,3,2,4,2,4,3,4,3,1,4,0,2,3,4,4,4,3,3,3,4,4,4,3,4,1,3,4,3,2,1,2,1,3,3,3,4,4,3,3,5,0,4,0,3,0,4,3,3,3,2,1,0,3,0,0,3,3),
( 0,4,0,3,0,3,0,3,0,3,5,5,3,3,3,3,4,3,4,3,3,3,4,4,4,3,3,3,3,4,3,5,3,3,1,3,2,4,5,5,5,5,4,3,4,5,5,3,2,2,3,3,3,3,2,3,3,1,2,3,2,4,3,3,3,4,0,4,0,2,0,4,3,2,2,1,2,0,3,0,0,4,1)
);

constructor TJapaneseContextAnalysis.Create;
begin
	inherited Create;
  Reset;
end;

destructor TJapaneseContextAnalysis.Destroy;
begin

  inherited;
end;

procedure TJapaneseContextAnalysis.HandleOneChar(aStr: PChar;  aCharLen: integer);
var
  order: PRInt32; (*if we received enough data, stop here   *)
begin
  if mTotalRel > MAX_REL_THRESHOLD then
    mDone:= TRUE;
  if mDone then
    exit;
    (*Only 2-bytes characters are of our interest*)
  if (aCharLen=2) then
  	order := GetOrder(aStr)
  else
  	order := -1;
  if (order <> -1) and (mLastCharOrder <> -1) then
    begin
      inc(mTotalRel);
      inc(mRelSample[jp2CharContext[mLastCharOrder][order]]);
      (*count this sequence to its category counter*)
    end;
  mLastCharOrder:= order;
end;

function TJapaneseContextAnalysis.GotEnoughData: Boolean;
begin
  Result := mTotalRel > ENOUGH_REL_THRESHOLD;
end;

function TJapaneseContextAnalysis.GetConfidence: float;
begin
  (*This is just one way to calculate confidence. It works well for me.*)
  if mTotalRel > MINIMUM_DATA_THRESHOLD then
  	Result := (mTotalRel - mRelSample[0]) div mTotalRel
  else
    Result := DONT_KNOW;
end;

procedure TJapaneseContextAnalysis.HandleData(const aBuf: PChar; aLen: integer);
var
  charLen: PRUint32;
  order: PRInt32;
  i: integer;
begin
  if mDone then
	  exit;
  (*The buffer we got is byte oriented, and a character may span in more than one*)
  (*buffers. In case the last one or two byte in last buffer is not complete, we *)
  (*record how many byte needed to complete that character and skip these bytes here.*)
  (*We can choose to record those bytes as well and analyse the character once it *)
  (*is complete, but since a character will not make much difference, by simply skipping*)
  (*this character will simply our logic and improve performance.*)
  i := mNeedToSkipCharNum;
  while i < integer(aLen) do
    begin
      order := GetOrder(aBuf+i, @charLen);
      i := i + integer(charLen);
      if i > integer(aLen) then
        begin
          mNeedToSkipCharNum := i - aLen;
          mLastCharOrder := -1;
        end
      else
        begin
          if (order <> -1) and (mLastCharOrder <> -1) then
            begin
              inc(mTotalRel);
              if mTotalRel > MAX_REL_THRESHOLD then
                begin
                  mDone:= TRUE;
                  break; {<= !!!b possible in "switch" - then remove this line}
                end;
              inc(mRelSample[jp2CharContext[mLastCharOrder][order]]);
            end;
          mLastCharOrder:= order;
        end;
    end;
end;

procedure TJapaneseContextAnalysis.Reset;
var
	i: integer;
begin
  mTotalRel := 0;
  for i := 0 to Pred(NUM_OF_CATEGORY) do
	  mRelSample[i] := 0;
  mNeedToSkipCharNum := 0;
  mLastCharOrder := -1;
  mDone := FALSE;
end;

		{ TSJISContextAnalysis }

function TSJISContextAnalysis.GetOrder(str: PChar; charLen: pPRUint32): PRInt32;
begin
  (*find out current char's byte length*)
  if (byte(str^) >= $81) and
  	 (byte(str^) <= $9f) or
     (byte(str^) >= $e0) and
     (byte(str^) <= $fc) then
  	charLen^:=2
  else
  	charLen^:=1;
  (*return its order if it is hiragana*)
  if (str^ = #$82) and
  	(byte((str+1)^) >= $9f) and
    (byte((str+1)^) <= $f1) then
	  Result := byte((str+1)^) - $9f
  else
    Result:= -1;
end;

function TSJISContextAnalysis.GetOrder(str: PChar): PRInt32;
begin
	(*We only interested in Hiragana, so first byte is '\202'*)
  if (str[0]=#$82) and
  		(byte(str[1]) >= $9f) and
      (byte(str[1]) <= $f1)  then
      Result := byte(str[1]) - $9f
	else
  	Result := -1;
end;

		{ TEUCJPContextAnalysis }

function TEUCJPContextAnalysis.GetOrder(str: PChar;  charLen: pPRUint32): PRInt32;
begin
  (*find out current char's byte length*)
  if (byte(str^) = $8e) or
  	 (byte(str^) >= $a1) and
     (byte(str^) <= $fe) then
  	charLen^ := 2
  else
	  if byte(str^) = $8f then
    	charLen^ := 3
  	else
  		charLen^ := 1;
  (*return its order if it is hiragana*)
  if (byte(str^) = $a4) and
  	 (byte((str+1)^) >= $a1) and
     (byte((str+1)^) <= $f3) then
    Result := byte((str+1)^) - $a1
	else
    Result:= -1;
end;

function TEUCJPContextAnalysis.GetOrder(str: PChar): PRInt32;
begin
  if (str[0]=#$A4) and
  		(byte(str[1]) >= $a1) and
      (byte(str[1]) <= $f3) then
    Result := byte(str[1]) - $a1
  else
  	Result := -1;
end;

end.
