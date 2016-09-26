/***************************************************************************************** 
* QUERY:    RDA Accounting File Extract
* PURPOSE:  Produces the output of the Standard Accounting file for Replicated Database Access
* NOTES:    
* CREATED:  Chris Kutsch (06/19/2012)
* MODIFIED 
* DATE          AUTHOR     DESCRIPTION 
*----------------------------------------------------------------------------------------- 
* {date}      {developer} {brief modification description} 
*****************************************************************************************/
Set Concat_Null_Yields_Null OFF;
SET NoCount ON; 
Declare
    @StoreID    varchar(11) 
,   @MinDate    datetime 
,   @MaxDate    datetime 
,   @JB         bit
/*                SQL VARS                  */
/********************************************/
Select
    @StoreID    = ''    -- 11 Digit Store ID or 5 Digit Merchant ID
,   @MinDate    = ''    -- Export Minimum Transaction Date
,   @MaxDate    = ''    -- Export Maximum Transaction Date
,   @JB         = 0     -- DO NOT CHANGE ( Job Mode )
/********************************************/
Declare @DailyAccountingReport Table 
(   Merchant_Id                         varchar (5) NULL 
,   Loan_Originating_Store_Id           char (11) NULL 
,   Transaction_Originating_Store_Id    char (11) NULL 
,   Loan_Id                             numeric (18,    0) NULL 
,   Cust_Ssn                            char (9) NULL 
,   Cust_Name                           varchar (92) NULL 
,   Loan_Orig_Date                      datetime NULL 
,   Loan_Due_Date                       datetime NULL 
,   Loan_Type                           char(1) NULL 
,   Loan_Status                         char (1) NULL 
,   OC_CollectionDate                   datetime NULL 
,   Assigned_Collector                  varchar(20) NULL 
,   Emp_User_Id                         varchar (20) NULL 
,   Tran_Date_Time                      datetime NULL 
,   Tran_Id                             numeric (19,    0) Not NULL 
,   Tran_Lynk_Id                        numeric (18,    0) NULL 
,   Tran_Type_Id                        int NULL 
,   Tran_Mode                           varchar (1) NULL 
,   Total_Amount_Of_Transaction         money NULL 
,   Tran_Account                        int NULL 
,   Fee_Type                            char (1) NULL 
,   Loan_Disburse_Subtype               int NULL 
,   Payment_Sub_Type                    int NULL 
,   Check_Number                        varchar(20) NULL 
,   Returntype                          int NULL 
,   Return_Item_Count                   int NULL 
,   Cust_State                          Char(2) NULL 
,   ACH_No                              numeric (18,    0) NULL 
,   Emp_Origin_UserID                   varchar (20) NULL 
) 
-- ****************************************************************************/ 
-- ****************************************************************************/ 
--    Variable Manipulation 
-- ****************************************************************************/ 
-- ****************************************************************************/ 
If @JB = 0 
 Begin 
    Select @MinDate = Convert ( varchar, @MinDate, 101 ) 
    Select @MaxDate = DateAdd ( d, 1, Convert ( varchar, @MaxDate, 101 ) ) 
 End 

Declare 
    @MerchantNo char(5) 
,   @StoreNo    varchar(11) 
,   @IsCSO      bit 

SET @StoreNo = NULL 
SET @IsCSO = 0 

If Len (Ltrim ( Rtrim ( @StoreID ) ) ) = 11 
 Begin 
    SET @StoreNo = @StoreID 
    SET @MerchantNo = Left ( @StoreID, 5 ) 
 End 
Else 
    SET @MerchantNo = @StoreID 

If Exists(Select RateID From dbo.ca_RateMaster WITH (NOLOCK) Where StoreID Like @MerchantNo+'%' AND CSOType=1) SET @IsCSO = 1;
-- ****************************************************************************/ 
 

-- ********************************************************************************************/ 
-- Only the Tran Account and Total_Amount_Of_Transaction is different 
--  for the first 3 queries. Tran Account 1- Principal,2-Fin Charge,3-Fee Charge 
-- Loans First 
-- ******************************LOANS SECTION START ******************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_SSN 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_Userid As Emp_User_Id 
    ,   la.Date_Created As Tran_Date_Time 
    ,   la.Appl_No As Tran_Id 
    ,   NULL As Tran_Lynk_Id 
    ,   'tran_Type_Id' = Case la.Loan_Type 
                            When 's' Then 1 
                            When 'r' Then 2 
                          End 
    ,   la.Disb_Mode As Tran_Mode 
    ,   Req_Loan_Amt As Total_Amount_Of_Transaction 
    ,   1 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   la.PrintedCheckNo As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   ACH_No= (Case la.Loan_Type WHEN 'S' THEN ap.ACH_No Else NULL  END) 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID
 
From    dbo.ca_Loan_Appl la WITH (NOLOCK) 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_ACH_Processed ap WITH (NOLOCK) ON la.Appl_no=ap.Appl_No 
                    And ap.Tran_Code='22' 
                    And ap.ACH_For = 'C' 
                    AND ap.ACH_Code = 'SND' 
                    AND ap.ACH_Sent_Status = 'S' 
                    AND ap.IsDeleted = 0 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id 
                    AND ou.User_ID=la.origin_user 
Where   la.Date_Created >= @minDate And 
        la.Date_Created < @maxDate And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        la.Appl_Status = 'A' And 
        la.Loan_Status In ( 'N', 'O', 'B', 'C', 'R', 'V', 'P', 'D' ) And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
-- ****************************************************************************/ 
--Fin charge / CSOFee 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_Userid As Emp_User_Id 
    ,   la.Date_Created As Tran_Date_Time 
    ,   la.Appl_No As Tran_Id 
    ,   NULL As Tran_Lynk_Id 
    ,   'tran_Type_Id' = Case la.Loan_Type 
                            When 's' Then 1 
                            When 'r' Then 2 
                          End 
    ,   la.Disb_Mode As Tran_Mode 
    ,   Case r.CSOType 
            When 1 Then ISNULL(r.Origination_Fee,0) 
            Else la.Fin_Charge 
        End As Total_Amount_Of_Transaction 
    ,   2 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   la.PrintedCheckNo As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   ACH_No= (Case la.Loan_Type WHEN 'S' THEN ap.ACH_No Else NULL  END) 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
From    dbo.ca_Loan_Appl la WITH (NOLOCK) 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_ACH_Processed ap WITH (NOLOCK) ON la.Appl_no=ap.Appl_No 
                    And ap.Tran_Code = '22' 
                    And ap.ACH_For = 'C' 
                    AND ap.ACH_Code = 'SND' 
                    AND ap.ACH_Sent_Status = 'S' 
                    AND ap.IsDeleted = 0 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Left Join 
        dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
        
Where   la.Date_Created >= @minDate And 
        la.Date_Created < @maxDate And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        la.Appl_Status = 'A' And 
        la.Loan_Status In ( 'N', 'O', 'B', 'C', 'R', 'V', 'P', 'D' ) And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--InterestFee for CSO 
-- ****************************************************************************/ 
If @IsCSO = 1 
 BEGIN 
    Insert Into @DailyAccountingReport 
    Select 
            c.Cust_MerchantID As Merchant_Id 
        ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
        ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
        ,   la.Appl_No As Loan_Id 
        ,   la.Cust_Ssn 
        ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
        ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
        ,   la.Req_Due_Date As Loan_Due_Date 
        ,   la.Loan_Type 
        ,   la.Loan_Status 
        ,   co.PlacedIntoCollections As O_Collection_Date 
        ,   co.Assigned_User_ID As Assigned_Collector 
        ,   u.Merchant_Userid As Emp_User_Id 
        ,   la.Date_Created As Tran_Date_Time 
        ,   la.Appl_No As Tran_Id 
        ,   NULL As Tran_Lynk_Id 
        ,   'tran_Type_Id' = Case la.Loan_Type 
                                When 's' Then 1 
                                When 'r' Then 2 
                              End 
        ,   la.Disb_Mode As Tran_Mode 
        ,   ISNULL(r.Interest_Fee,0) As Total_Amount_Of_Transaction 
        ,   6 As Tran_Account 
        ,   NULL As Fee_Type 
        ,   la.Cashdisbmode As Loan_Disburse_Subtype 
        ,   NULL As Payment_Sub_Type 
        ,   la.PrintedCheckNo As Check_Number 
        ,   NULL As Returntype 
        ,   NULL As Return_Item_Count 
        ,   c.Cust_State 
        ,   ACH_No= (Case la.Loan_Type WHEN 'S' THEN ap.ACH_No Else NULL  END) 
        ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
    From    dbo.ca_Loan_Appl la WITH (NOLOCK) 
	Inner Join 
            dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
	Inner Join 
            dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
	Inner Join 
            dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
	Left Join 
            dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
	Left Join 
            dbo.ca_ACH_Processed ap WITH (NOLOCK) ON la.Appl_no=ap.Appl_No 
                        And ap.Tran_Code = '22' 
                        And ap.ACH_For = 'C' 
                        AND ap.ACH_Code = 'SND' 
                        AND ap.ACH_Sent_Status = 'S' 
                        AND ap.IsDeleted = 0 
	Left Join 
            dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
    Where   
			la.Date_Created >= @minDate And 
            la.Date_Created < @maxDate And 
            la.Merch_Store_ID like @MerchantNo + '%' And 
            la.Appl_Status = 'A' And 
            la.Loan_Status In ( 'N', 'O', 'B', 'C', 'R', 'V', 'P', 'D' ) And 
            ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
            la.User_Id = u.User_Id;
 END 
--**************************************LOANS SECTION END ****************************************** 

--**************************************VOIDS SECTION START **************************************** 
--Voids Second 
--Principal 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   v.Date_Created As Tran_Date_Time 
    ,   v.Void_Id As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   3 As 'tran_Type_Id' 
    ,   la.Disb_Mode As Tran_Mode 
    ,   Req_Loan_Amt As Total_Amount_Of_Transaction 
    ,   1 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   ACH_No= (Case la.Loan_Type WHEN 'S' THEN ap.ACH_No Else NULL  END) 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
From    dbo.ca_Void v WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On v.Void_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No
Left Join 
        dbo.ca_ACH_Processed ap WITH (NOLOCK) ON la.Appl_no=ap.Appl_No  
                    And ap.Tran_Code = '22' 
                    And ap.ACH_For = 'C' 
                    AND ap.ACH_Code = 'SND' 
                    AND ap.ACH_Sent_Status = 'S' 
                    AND ap.IsDeleted = 0 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		v.Date_Created >= @minDate And 
        v.Date_Created < @maxDate And 
        v.Void_Type = 'L' And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--Voids Second 
--Finance charge / CSOFee 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   v.Date_Created  As Tran_Date_Time 
    ,   v.Void_Id As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   3 As 'tran_Type_Id' 
    ,   la.Disb_Mode As Tran_Mode 
    ,   Case r.CSOType 
            When 1 Then ISNULL(r.Origination_Fee,0) 
            Else la.Fin_Charge 
        End As Total_Amount_Of_Transaction 
    ,   2 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   ACH_No= (Case la.Loan_Type WHEN 'S' THEN ap.ACH_No Else NULL  END) 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 

From    dbo.ca_Void v WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On v.Void_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_ACH_Processed ap WITH (NOLOCK) ON la.Appl_no=ap.Appl_No 
                    And ap.Tran_Code = '22' 
                    And ap.ACH_For = 'C' 
                    AND ap.ACH_Code = 'SND' 
                    AND ap.ACH_Sent_Status = 'S' 
                    AND ap.IsDeleted = 0 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Left Join 
        dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
Where   
		v.Date_Created >= @minDate And 
        v.Date_Created < @maxDate And 
        v.Void_Type = 'L' And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--InterestFee for CSO 
-- ****************************************************************************/ 
If @IsCSO = 1 
 BEGIN 
    Insert Into @DailyAccountingReport 
    Select 
            c.Cust_MerchantID As Merchant_Id 
        ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
        ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
        ,   la.Appl_No As Loan_Id 
        ,   la.Cust_Ssn 
        ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
        ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
        ,   la.Req_Due_Date As Loan_Due_Date 
        ,   la.Loan_Type 
        ,   la.Loan_Status 
        ,   co.PlacedIntoCollections As O_Collection_Date 
        ,   co.Assigned_User_ID As Assigned_Collector 
        ,   u.Merchant_UserID As Emp_User_ID 
        ,   v.Date_Created  As Tran_Date_Time 
        ,   v.Void_Id As Tran_Id 
        ,   la.Appl_No As Tran_Lynk_Id 
        ,   3 As 'tran_Type_Id' 
        ,   la.Disb_Mode As Tran_Mode 
        ,   ISNULL(r.Interest_Fee,0) As Total_Amount_Of_Transaction 
        ,   6 As Tran_Account 
        ,   NULL As Fee_Type 
        ,   la.Cashdisbmode As Loan_Disburse_Subtype 
        ,   NULL As Payment_Sub_Type 
        ,   NULL As Check_Number 
        ,   NULL As Returntype 
        ,   NULL As Return_Item_Count 
        ,   c.Cust_State 
        ,   ACH_No= (Case la.Loan_Type WHEN 'S' THEN ap.ACH_No Else NULL  END) 
        ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
    From    dbo.ca_Void v WITH (NOLOCK) 
	Inner Join 
            dbo.ca_Loan_Appl la WITH (NOLOCK) On v.Void_No = la.Appl_No 
	Inner Join 
            dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
	Inner Join 
            dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
	Inner Join 
            dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
	Left Join 
            dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
	Left Join 
            dbo.ca_ACH_Processed ap WITH (NOLOCK) ON la.Appl_no=ap.Appl_No  
                        And ap.Tran_Code = '22' 
                        And ap.ACH_For = 'C' 
                        AND ap.ACH_Code = 'SND' 
                        AND ap.ACH_Sent_Status = 'S' 
                        AND ap.IsDeleted = 0 
	Left Join 
            dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
    Where   
			v.Date_Created >= @minDate And 
            v.Date_Created < @maxDate And 
            v.Void_Type = 'L' And 
            la.Merch_Store_ID like @MerchantNo + '%' And 
            ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
            la.User_Id = u.User_Id;
 END 
 
-- ****************************************************************************/ 
--Voids Second 
--Fee charge 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   v.Date_Created  As Tran_Date_Time 
    ,   v.Void_Id As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   3 As 'tran_Type_Id' 
    ,   la.Disb_Mode As Tran_Mode 
    ,   ISNULL( fcd.Amount, 0 ) As Total_Amount_Of_Transaction 
    ,   3 As Tran_Account 
    ,   fcd.Feetypecode As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   ACH_No= (Case la.Loan_Type WHEN 'S' THEN ap.ACH_No Else NULL  END) 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
From    dbo.ca_Void v WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On v.Void_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_ACH_Processed ap WITH (NOLOCK) ON la.Appl_no=ap.Appl_No  
                    And ap.Tran_Code = '22' 
                    And ap.ACH_For = 'C' 
                    AND ap.ACH_Code = 'SND' 
                    AND ap.ACH_Sent_Status = 'S' 
                    AND ap.IsDeleted = 0 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Inner Join 
        dbo.ca_Feechargedetails fcd WITH (NOLOCK) On la.Appl_No = fcd.Appl_No 
Where   
		v.Date_Created >= @minDate And 
        v.Date_Created < @maxDate And 
        v.Void_Type = 'L' And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        fcd.Feetypecode Not In ( 'B', 'X' ) And 
        la.User_Id = u.User_Id;
--**************************************VOIDS SECTION END **************************************** 

--**************************************PAYMENTS SECTION START **************************************** 
--Payments Third 
--Principle 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   p.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   p.Pmt_Date As Tran_Date_Time 
    ,   p.Pmt_Tran_No As Tran_Id 
    ,   p.Refno As Tran_Lynk_Id 
    ,   'tran_Type_Id' = Case 
                            When p.Pmt_Mode = 'G' Then 9 
                            When p.Pmt_Type = 'X' Then 1 
                            When p.Pmt_Type = 'B' Then 1 
                            When p.Pmt_Type = 'S' Then 4 
                            When p.Pmt_Type = 'R' Then 5 
                            When p.Pmt_Type = 'N' Then 6 
                            When p.Pmt_Type = 'A' Then 27 
                            When p.Pmt_Type = 'P' Then 7 
                            When p.Pmt_Type = 'G' Then 8 
                            When p.Pmt_Type = 'U' Then 16 
                            When p.Pmt_Type = 'W' Then 21 
                            When p.Pmt_Type = '1' Then 22 
                            When p.Pmt_Type = 'E' Then 24 
                            When p.Pmt_Type = '9' Then 24 
                            When p.Pmt_Type = 'K' Then 25 
                            WHEN p.Pmt_Type = 'Q' THEN 29 
                            Else 23 
                         End 
    ,   p.Pmt_Mode As Tran_Mode 
    ,   Total_Amount_Of_Transaction = ISNULL(p.Principle_Paid,    0) 
    ,   1 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   Case 
            WHEN p.Pmt_Mode <> 'C' THEN NULLIF(p.Misintfield1,0) 
            ELSE p.Misintfield1 
        END As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   Returntype = Case p.Pmt_Type 
                        When 'n' Then 
                            Case p2.Pmt_Type 
                            When 's' Then 1 
                            When 'r' Then 1 
                            When 'p' Then 2 
                            When 'k' Then 2 
                            When 'g' Then 3 
                            WHEN 'Q' THEN 4 
                            End 
                        Else NULL 
                     End 
    ,   Return_Item_Count = ( Select Count ( ar.Achretid ) As Returncount 
                              From dbo.ca_Achreturns ar WITH (NOLOCK) 
							  Inner Join 
                                   dbo.ca_ACH_Processed ap WITH (NOLOCK) On ar.Achno = ap.Ach_No 
                              Where ap.Appl_No = p.Appl_No ) 
    ,   c.Cust_State 
    ,   ap.ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 

From    dbo.ca_Payment p WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On p.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Payment p2 WITH (NOLOCK) On p.Refno = p2.Pmt_Tran_No 
Left Join 
        dbo.ca_ACH_Processed ap WITH (NOLOCK) ON ap.Pmt_No=p2.Pmt_Tran_No AND ap.IsDeleted=0 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		p.Date_Created >= @minDate And 
        p.Date_Created < @maxDate And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        ISNULL ( p.Principle_Paid, 0 ) <> 0 And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--Payments Third 
--Fin charge / CSOFee 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   p.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   p.Pmt_Date As Tran_Date_Time 
    ,   p.Pmt_Tran_No As Tran_Id 
    ,   p.Refno As Tran_Lynk_Id 
    ,   'tran_Type_Id' = Case 
                            When p.Pmt_Mode = 'G' Then 9 
                            When p.Pmt_Type = 'X' Then 1 
                            When p.Pmt_Type = 'B' Then 1 
                            When p.Pmt_Type = 'S' Then 4 
                            When p.Pmt_Type = 'R' Then 5 
                            When p.Pmt_Type = 'N' Then 6 
                            When p.Pmt_Type = 'A' Then 27 
                            When p.Pmt_Type = 'P' Then 7 
                            When p.Pmt_Type = 'G' Then 8 
                            When p.Pmt_Type = 'U' Then 16 
                            When p.Pmt_Type = 'W' Then 21 
                            When p.Pmt_Type = '1' Then 22 
                            When p.Pmt_Type = 'E' Then 24 
                            When p.Pmt_Type = '9' Then 24 
                            When p.Pmt_Type = 'K' Then 25 
                            WHEN p.Pmt_Type = 'Q' THEN 29 
                            Else 23 
                         End 
    ,   p.Pmt_Mode As Tran_Mode 
    ,   Total_Amount_Of_Transaction = 
            Case When p.Pmt_Type IN ('X','B','S','R','N','A','P','G','W','K') AND r.CSOType=1 Then 
                Case When ISNULL(p.FinCharge_Paid,0)> 0 AND ISNULL(p.FinCharge_Paid,0) >= ISNULL(r.FinCharge,0) 
                        Then ISNULL(r.Origination_Fee,0) 
                    When ISNULL(p.FinCharge_Paid,0)> 0 AND ISNULL(p.FinCharge_Paid,0) < ISNULL(r.FinCharge,0) 
                        Then Round((ISNULL(p.FinCharge_Paid,0)*ISNULL(r.Origination_Fee,0))/ISNULL(r.FinCharge,0),2) 
                    When ISNULL(p.FinCharge_Paid,0) < 0 AND ISNULL(p.FinCharge_Paid,0)>= ISNULL(r.FinCharge,0) 
                        Then ISNULL(r.Origination_Fee,0) *-1 
                    When ISNULL(p.FinCharge_Paid,0)< 0 AND ISNULL(p.FinCharge_Paid,0)< ISNULL(r.FinCharge,0) AND ISNULL(r.FinCharge,0)<>0 
                        Then Round(((ISNULL(p.FinCharge_Paid,0)*ISNULL(r.Origination_Fee,0))/ISNULL(r.FinCharge,0)),2) 
                    ELSE 0 
                End 
            ELSE 
                ISNULL (p.Fincharge_Paid,0) 
            END 
    ,   2 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   Case 
            WHEN p.Pmt_Mode <> 'C' THEN 
                NULLIF(p.Misintfield1,0) 
            ELSE 
                p.Misintfield1 
        END As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   Returntype = Case p.Pmt_Type 
                        When 'n' Then 
                            Case p2.Pmt_Type 
                                When 's' Then 1 
                                When 'r' Then 1 
                                When 'p' Then 2 
                                When 'k' Then 2 
                                When 'g' Then 3 
                                WHEN 'Q' THEN 4 
                            End 
                        Else NULL 
                     End 
    ,   Return_Item_Count = (   Select Count ( ar.Achretid ) As Returncount 
                                From  dbo.ca_Achreturns ar WITH (NOLOCK) Inner Join 
                                      dbo.ca_ACH_Processed ap WITH (NOLOCK) On ar.Achno = ap.Ach_No 
                                Where ap.Appl_No = p.Appl_No) 
    ,   c.Cust_State 
    ,   ap.ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
From    dbo.ca_Payment p WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On p.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Payment p2 WITH (NOLOCK) On p.Refno = p2.Pmt_Tran_No 
Left Join 
        dbo.ca_ACH_Processed ap WITH (NOLOCK) ON ap.Pmt_No=p2.Pmt_Tran_No AND ap.IsDeleted=0 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		p.Date_Created >= @minDate And 
        p.Date_Created < @maxDate And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        IsNULL ( p.Fincharge_Paid, 0 ) <> 0 And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--InterestFee CSO --> Pmt Types: 'X','B','S','R','N','A','P','G','W','K' only 
-- ****************************************************************************/ 
If @IsCSO = 1 
 BEGIN 
    Insert Into @DailyAccountingReport 
    Select 
            c.Cust_MerchantID As Merchant_Id 
        ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
        ,   p.Merch_Store_Id As Transaction_Originating_Store_Id 
        ,   la.Appl_No As Loan_Id 
        ,   la.Cust_Ssn 
        ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
        ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
        ,   la.Req_Due_Date As Loan_Due_Date 
        ,   la.Loan_Type 
        ,   la.Loan_Status 
        ,   co.PlacedIntoCollections As O_Collection_Date 
        ,   co.Assigned_User_ID As Assigned_Collector 
        ,   u.Merchant_UserID As Emp_User_ID 
        ,   p.Pmt_Date As Tran_Date_Time 
        ,   p.Pmt_Tran_No As Tran_Id 
        ,   p.Refno As Tran_Lynk_Id 
        ,    'tran_Type_Id' = Case 
                                When p.Pmt_Mode = 'G' Then 9 
                                When p.Pmt_Type = 'X' Then 1 
                                When p.Pmt_Type = 'B' Then 1 
                                When p.Pmt_Type = 'S' Then 4 
                                When p.Pmt_Type = 'R' Then 5 
                                When p.Pmt_Type = 'N' Then 6 
                                When p.Pmt_Type = 'A' Then 27 
                                When p.Pmt_Type = 'P' Then 7 
                                When p.Pmt_Type = 'G' Then 8 
                                When p.Pmt_Type = 'W' Then 21 
                                When p.Pmt_Type = 'K' Then 25 
                                WHEN p.Pmt_Type = 'Q' THEN 29 
                                Else 23 
                              End 
        ,   p.Pmt_Mode As Tran_Mode 
        ,   Total_Amount_Of_Transaction = 
                Case When ISNULL(p.FinCharge_Paid,0)> 0 AND ISNULL(p.FinCharge_Paid,0) >= ISNULL(r.FinCharge,0) 
                        Then ISNULL(r.Interest_Fee,0) 
                    When ISNULL(p.FinCharge_Paid,0)> 0 AND ISNULL(p.FinCharge_Paid,0) < ISNULL(r.FinCharge,0) 
                        Then Round((ISNULL(p.FinCharge_Paid,0)*ISNULL(r.Interest_Fee,0))/ISNULL(r.FinCharge,0),2) 
                    When ISNULL(p.FinCharge_Paid,0) < 0 AND ISNULL(p.FinCharge_Paid,0)>= ISNULL(r.FinCharge,0) 
                        Then ISNULL(r.Interest_Fee,0) *-1 
                    When ISNULL(p.FinCharge_Paid,0)< 0 AND ISNULL(p.FinCharge_Paid,0)< ISNULL(r.FinCharge,0) AND ISNULL(r.FinCharge,0)<>0 
                        Then Round(((ISNULL(p.FinCharge_Paid,0)*ISNULL(r.Interest_Fee,0))/ISNULL(r.FinCharge,0)),2) 
                ELSE 
                    0 
                End 
        ,   6 As Tran_Account 
        ,   NULL As Fee_Type 
        ,   NULL As Loan_Disburse_Subtype 
        ,   Case 
                WHEN p.Pmt_Mode <> 'C' THEN 
                    NULLIF(p.Misintfield1,0) 
                ELSE 
                    p.Misintfield1 
            END As Payment_Sub_Type 
        ,   NULL As Check_Number 
        ,   Returntype = Case p.Pmt_Type 
                            When 'n' Then 
                                Case p2.Pmt_Type 
                                    When 's' Then 1 
                                    When 'r' Then 1 
                                    When 'p' Then 2 
                                    When 'k' Then 2 
                                    When 'g' Then 3 
                                    WHEN 'Q' THEN 4 
                                End 
                            Else NULL 
                         End 
        ,   Return_Item_Count = ( Select Count ( ar.Achretid ) As Returncount 
                                  From dbo.ca_Achreturns ar WITH (NOLOCK) Inner Join 
                                       dbo.ca_ACH_Processed ap WITH (NOLOCK) On ar.Achno = ap.Ach_No 
                                  Where ap.Appl_No = p.Appl_No) 
        ,   c.Cust_State 
        ,   ap.ACH_No 
        ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
    From    dbo.ca_Payment p WITH (NOLOCK) 
	Inner Join 
            dbo.ca_Loan_Appl la WITH (NOLOCK) On p.Appl_No = la.Appl_No 
	Inner Join 
            dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
	Inner Join 
            dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
	Inner Join 
            dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
	Left Join 
            dbo.ca_Payment p2 WITH (NOLOCK) On p.Refno = p2.Pmt_Tran_No 
	Left Join 
            dbo.ca_ACH_Processed ap WITH (NOLOCK) ON ap.Pmt_No=p2.Pmt_Tran_No AND ap.IsDeleted=0 
	Left Join 
            dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
	Left Join 
            dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
    Where   
			p.Date_Created >= @minDate And 
            p.Date_Created < @maxDate And 
            la.Merch_Store_ID like @MerchantNo + '%' And 
            p.Pmt_Type IN ('X','B','S','R','N','A','P','G','W','K') And 
            ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
            IsNULL ( p.Fincharge_Paid, 0 ) <> 0 And 
            la.User_Id = u.User_Id;
 END 
 
-- ****************************************************************************/ 
--Payments Third 
--Fees Paid 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   p.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   p.Pmt_Date As Tran_Date_Time 
    ,   p.Pmt_Tran_No As Tran_Id 
    ,   p.Refno As Tran_Lynk_Id 
    ,   'tran_Type_Id' = Case 
                            When p.Pmt_Mode = 'G' Then 9 
                            When p.Pmt_Type = 'X' Then 1 
                            When p.Pmt_Type = 'B' Then 1 
                            When p.Pmt_Type = 'S' Then 4 
                            When p.Pmt_Type = 'R' Then 5 
                            When p.Pmt_Type = 'N' Then 6 
                            When p.Pmt_Type = 'A' Then 27 
                            When p.Pmt_Type = 'P' Then 7 
                            When p.Pmt_Type = 'G' Then 8 
                            When p.Pmt_Type = 'U' Then 16 
                            When p.Pmt_Type = 'W' Then 21 
                            When p.Pmt_Type = '1' Then 22 
                            When p.Pmt_Type = 'E' Then 24 
                            When p.Pmt_Type = '9' Then 24 
                            When p.Pmt_Type = 'K' Then 25 
                            WHEN p.Pmt_Type = 'Q' THEN 29 
                            Else 23 
                         End 
    ,   p.Pmt_Mode As Tran_Mode 
    ,   Total_Amount_Of_Transaction = ISNULL ( p.latecharge_Paid, 0 ) + 
                                      ISNULL ( p.Othcharge_Paid, 0 ) + 
                                      ISNULL ( p.Feecharge_Paid, 0 ) 
    ,   'tran_Account' = Case 
                            When p.Pmt_Type = 'b' Then 4 
                            When p.Pmt_Type = 'x' Then 5 
                            Else 3 
                         End 
    ,   p.Pmt_Type As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   Case 
            WHEN p.Pmt_Mode <> 'C' THEN 
                NULLIF(p.Misintfield1,0) 
            ELSE 
                p.Misintfield1 
        END As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   Returntype = Case p.Pmt_Type 
                        When 'n' Then 
                            Case p2.Pmt_Type 
                                When 's' Then 1 
                                When 'r' Then 1 
                                When 'p' Then 2 
                                When 'k' Then 2 
                                When 'g' Then 3 
                                WHEN 'Q' THEN 4 
                            End 
                        Else NULL 
                     End 
    ,   Return_Item_Count = (   Select Count ( ar.Achretid ) As Returncount 
                                From dbo.ca_Achreturns ar WITH (NOLOCK) Inner Join 
                                     dbo.ca_ACH_Processed ap WITH (NOLOCK) On ar.Achno = ap.Ach_No 
                                Where ap.Appl_No = p.Appl_No) 
    ,   c.Cust_State 
    ,   ap.ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 

From    dbo.ca_Payment p WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On p.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Payment p2 WITH (NOLOCK) On p.Refno = p2.Pmt_Tran_No 
Left Join 
        dbo.ca_ACH_Processed ap WITH (NOLOCK) ON ap.Pmt_No=p2.Pmt_Tran_No AND ap.IsDeleted = 0 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		p.Date_Created >= @minDate And 
        p.Date_Created < @maxDate And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
            isNULL ( p.latecharge_Paid, 0 ) + 
            isNULL ( p.Othcharge_Paid, 0 ) + 
            isNULL ( p.Feecharge_Paid, 0 ) <> 0 And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--Assessments/Waive interest 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   p.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   p.Pmt_Date As Tran_Date_Time 
    ,   la.Appl_No As Tran_Id 
    ,   p.Pmt_Tran_No As Tran_Lynk_Id 
    ,   'tran_Type_Id' = Case 
                            When ic.intcalc_Typecode = 'A' Then 20 
                            Else 21 
                         End 
    ,   p.Pmt_Mode As Tran_Mode 
    ,   ic.Amount As Total_Amount_Of_Transaction 
    ,   2 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   Case 
            WHEN p.Pmt_Mode <> 'C' THEN 
                NULLIF(p.Misintfield1,0) 
            ELSE p.Misintfield1 
        END As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   Returntype = Case p.Pmt_Type 
                        When 'n' Then 
                            Case p2.Pmt_Type 
                                When 's' Then 1 
                                When 'r' Then 1 
                                When 'p' Then 2 
                                When 'k' Then 2 
                                When 'g' Then 3 
                                WHEN 'Q' THEN 4 
                            End 
                        Else NULL 
                     End 
    ,   Return_Item_Count = (   Select Count ( ar.Achretid ) As Returncount 
                                From dbo.ca_Achreturns ar WITH (NOLOCK) Inner Join 
                                     dbo.ca_Ach_Processed ap WITH (NOLOCK) On ar.Achno = ap.Ach_No 
                                Where ap.Appl_No = p.Appl_No ) 
    ,   c.Cust_State 
    ,   NULL As ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 

From    dbo.ca_Payment p WITH (NOLOCK) 
Inner Join 
        dbo.ca_interest_Calc ic WITH (NOLOCK) On p.Pmt_Tran_No = ic.Pmt_Tran_No 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On p.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Payment p2 WITH (NOLOCK) On p.Refno = p2.Pmt_Tran_No 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		p.Date_Created >= @minDate And 
        p.Date_Created < @maxDate And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--PREPAYMENT 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   p.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   p.Pmt_Date As Tran_Date_Time 
    ,   p.Pmt_Tran_No As Tran_Id 
    ,   p.Refno As Tran_Lynk_Id 
    ,   'tran_Type_Id' = Case 
                            When p.Pmt_Type = 'Y' Then 26 
                            When p.Pmt_Type = '9' Then 24 
                            Else 23 
                         End 
    ,   p.Pmt_Mode As Tran_Mode 
    ,   Total_Amount_Of_Transaction = p.Pmt_Amt 
    ,   null As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   Case 
            WHEN p.Pmt_Mode <> 'C' THEN 
                NULLIF(p.Misintfield1,0) 
            ELSE 
                p.Misintfield1 
        END As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   Returntype = Case p.Pmt_Type 
                        When 'n' Then 
                            Case p2.Pmt_Type 
                                When 's' Then 1 
                                When 'r' Then 1 
                                When 'p' Then 2 
                                When 'k' Then 2 
                                When 'g' Then 3 
                                WHEN 'Q' THEN 4 
                            End 
                        Else NULL 
                     End 
    ,   Return_Item_Count = (   Select Count ( ar.Achretid ) As Returncount 
                                From dbo.ca_Achreturns ar WITH (NOLOCK) Inner Join 
                                     dbo.ca_ACH_Processed ap WITH (NOLOCK) On ar.Achno = ap.Ach_No 
                                Where ap.Appl_No = p.Appl_No ) 
    ,   c.Cust_State 
    ,   ap.ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 

From    dbo.ca_Payment p WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On p.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Payment p2 WITH (NOLOCK) On p.Refno = p2.Pmt_Tran_No 
Left Join 
        dbo.ca_ACH_Processed ap WITH (NOLOCK) ON ap.Pmt_No=p2.Pmt_Tran_No AND ap.IsDeleted=0 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		p.Date_Created >= @minDate And 
        p.Date_Created < @maxDate And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        IsNULL ( p.Principle_Paid, 0 ) = 0 And 
        IsNULL ( p.Fincharge_Paid, 0 ) = 0 And 
        IsNULL ( p.FeeCharge_Paid, 0 ) = 0 And 
        la.User_Id = u.User_Id AND 
        p.Pmt_Type in ('Y','9');
--**************************************PAYMENTS  END **************************************** 

--**************************************BANKRUPTCY SECTION START **************************************** 
--Bankruptcy charges Fourth 
--Principal 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   bc.Date_Created As Tran_Date_Time 
    ,   bc.Bc_No As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   28 As Tran_Type_Id 
    ,   NULL As Tran_Mode 
    ,   bc.Prinamt As Total_Amount_Of_Transaction 
    ,   1 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   NULL As ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
From    dbo.ca_Bankruptcy_charges bc WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On bc.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		bc.Date_Created >= @minDate And 
        bc.Date_Created < @maxDate And 
        bc.Bc_Flag = 'B' And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--Bankruptcy charges Fourth 
--Finance charge / CSOFee 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   bc.Date_Created As Tran_Date_Time 
    ,   bc.Bc_No As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   28 As Tran_Type_Id 
    ,   NULL As Tran_Mode 
    ,   Case 
            When r.CSOType=1 Then 
                Case When ISNULL(bc.Finamt,0)> 0 AND ISNULL(bc.Finamt,0) >= ISNULL(r.FinCharge,0) 
                        Then ISNULL(r.Origination_Fee,0) 
                    When ISNULL(bc.Finamt,0)> 0 AND ISNULL(bc.Finamt,0) < ISNULL(r.FinCharge,0) 
                        Then Round((ISNULL(bc.Finamt,0)*ISNULL(r.Origination_Fee,0))/ISNULL(r.FinCharge,0),2) 
                    When ISNULL(bc.Finamt,0) < 0 AND ISNULL(bc.Finamt,0)>= ISNULL(r.FinCharge,0) 
                        Then ISNULL(r.Origination_Fee,0) *-1 
                    When ISNULL(bc.Finamt,0)< 0 AND ISNULL(r.FinCharge,0)<>0 AND ISNULL(bc.Finamt,0)< ISNULL(r.FinCharge,0) 
                        Then Round(((ISNULL(bc.Finamt,0)*ISNULL(r.Origination_Fee,0))/ISNULL(r.FinCharge,0)),2) 
                ELSE 0 
                End 
            ELSE 
                ISNULL (bc.Finamt,    0) 
        END As Total_Amount_Of_Transaction 
    ,   2 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   NULL As ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 

From    dbo.ca_Bankruptcy_charges bc WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On bc.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		bc.Date_Created >= @minDate And 
        bc.Date_Created < @maxDate And 
        bc.Bc_Flag = 'B' And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--InterestFee for CSO 
-- ****************************************************************************/ 
If @IsCSO = 1 
 BEGIN 
    Insert Into @DailyAccountingReport 
    Select 
            c.Cust_MerchantID As Merchant_Id 
        ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
        ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
        ,   la.Appl_No As Loan_Id 
        ,   la.Cust_Ssn 
        ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
        ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
        ,   la.Req_Due_Date As Loan_Due_Date 
        ,   la.Loan_Type 
        ,   la.Loan_Status 
        ,   co.PlacedIntoCollections As O_Collection_Date 
        ,   co.Assigned_User_ID As Assigned_Collector 
        ,   u.Merchant_UserID As Emp_User_ID 
        ,   bc.Date_Created As Tran_Date_Time 
        ,   bc.Bc_No As Tran_Id 
        ,   la.Appl_No As Tran_Lynk_Id 
        ,   28 As Tran_Type_Id 
        ,   NULL As Tran_Mode 
        ,   Case 
                When r.CSOType=1 Then 
                    Case When ISNULL(bc.Finamt,0)> 0 AND ISNULL(bc.Finamt,0) >= ISNULL(r.FinCharge,0) 
                            Then ISNULL(r.Interest_Fee,0) 
                        When ISNULL(bc.Finamt,0)> 0 AND ISNULL(bc.Finamt,0) < ISNULL(r.FinCharge,0) 
                            Then Round((ISNULL(bc.Finamt,0)*ISNULL(r.Interest_Fee,0))/ISNULL(r.FinCharge,0),2) 
                        When ISNULL(bc.Finamt,0) < 0 AND ISNULL(bc.Finamt,0)>= ISNULL(r.FinCharge,0) 
                            Then ISNULL(r.Interest_Fee,0) *-1 
                        When ISNULL(bc.Finamt,0)< 0 AND ISNULL(r.FinCharge,0)<>0 AND ISNULL(bc.Finamt,0)< ISNULL(r.FinCharge,0) 
                            Then Round(((ISNULL(bc.Finamt,0)*ISNULL(r.Interest_Fee,0))/ISNULL(r.FinCharge,0)),2) 
                        ELSE 0 
                    End 
                ELSE 
                    ISNULL (bc.Finamt,    0) 
            END As Total_Amount_Of_Transaction 
        ,   6 As Tran_Account 
        ,   NULL As Fee_Type 
        ,   la.Cashdisbmode As Loan_Disburse_Subtype 
        ,   NULL As Payment_Sub_Type 
        ,   NULL As Check_Number 
        ,   NULL As Returntype 
        ,   NULL As Return_Item_Count 
        ,   c.Cust_State 
        ,   NULL As ACH_No 
        ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
    From    dbo.ca_Bankruptcy_charges bc WITH (NOLOCK) 
	Inner Join 
            dbo.ca_Loan_Appl la WITH (NOLOCK) On bc.Appl_No = la.Appl_No 
	Inner Join 
            dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
	Inner Join 
            dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
	Inner Join 
            dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
	Left Join 
            dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
	Left Join 
            dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
    Where   
			bc.Date_Created >= @minDate And 
            bc.Date_Created < @maxDate And 
            bc.Bc_Flag = 'B' And 
            la.Merch_Store_ID like @MerchantNo + '%' And 
            ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
            la.User_Id = u.User_Id;
 END 
 
-- ****************************************************************************/ 
--Bankruptcy charges Fourth 
--Fee charges 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   bc.Date_Created As Tran_Date_Time 
    ,   bc.Bc_No As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   28 As Tran_Type_Id 
    ,   NULL As Tran_Mode 
    ,   ISNULL(bc.Feeamt, 0) As Total_Amount_Of_Transaction 
    ,   3 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   NULL As ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
From    dbo.ca_Bankruptcy_charges bc WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On bc.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		bc.Date_Created >= @minDate And 
        bc.Date_Created < @maxDate And 
        bc.Bc_Flag = 'B' And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
--**************************************BANKRUPTCY SECTION END **************************************** 

--**************************************CHARGE OFF SECTION START **************************************** 
--Bankruptcy charges Fourth 
--Principal 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   bc.Date_Created As Tran_Date_Time 
    ,   bc.Bc_No As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   11 As Tran_Type_Id 
    ,   NULL As Tran_Mode 
    ,   bc.Prinamt As Total_Amount_Of_Transaction 
    ,   1 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   NULL As ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
From    dbo.ca_Bankruptcy_charges bc WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On bc.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		bc.Date_Created >= @minDate And 
        bc.Date_Created < @maxDate And 
        bc.Bc_Flag = 'C' And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--Bankruptcy charges Fourth 
--Finance charge / CSOFee 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   la.Date_Created As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   bc.Date_Created As Tran_Date_Time 
    ,   bc.Bc_No As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   11 As Tran_Type_Id 
    ,   NULL As Tran_Mode 
    ,   Case When r.CSOType=1 Then 
            Case When ISNULL(bc.Finamt,0)> 0 AND ISNULL(bc.Finamt,0) >= ISNULL(r.FinCharge,0) 
                    Then ISNULL(r.Origination_Fee,0) 
                When ISNULL(bc.Finamt,0)> 0 AND ISNULL(bc.Finamt,0) < ISNULL(r.FinCharge,0) 
                    Then Round((ISNULL(bc.Finamt,0)*ISNULL(r.Origination_Fee,0))/ISNULL(r.FinCharge,0),2) 
                When ISNULL(bc.Finamt,0) < 0 AND ISNULL(bc.Finamt,0)>= ISNULL(r.FinCharge,0) 
                    Then ISNULL(r.Origination_Fee,0) *-1 
                When ISNULL(bc.Finamt,0)< 0 AND ISNULL(r.FinCharge,0)<>0 AND ISNULL(bc.Finamt,0)< ISNULL(r.FinCharge,0) 
                    Then Round(((ISNULL(bc.Finamt,0)*ISNULL(r.Origination_Fee,0))/ISNULL(r.FinCharge,0)),2) 
                ELSE 0 
            End 
            ELSE 
                ISNULL (bc.Finamt,    0) 
        END As Total_Amount_Of_Transaction 
    ,   2 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   NULL As ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 

From    dbo.ca_Bankruptcy_charges bc WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On bc.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		bc.Date_Created >= @minDate And 
        bc.Date_Created < @maxDate And 
        bc.Bc_Flag = 'C' And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
        
-- ****************************************************************************/ 
--InterestFee for CSO 
-- ****************************************************************************/ 
If @IsCSO = 1 
 BEGIN 
    Insert Into @DailyAccountingReport 
    Select 
            c.Cust_MerchantID As Merchant_Id 
        ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
        ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
        ,   la.Appl_No As Loan_Id 
        ,   la.Cust_Ssn 
        ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
        ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
        ,   la.Req_Due_Date As Loan_Due_Date 
        ,   la.Loan_Type 
        ,   la.Loan_Status 
        ,   co.PlacedIntoCollections As O_Collection_Date 
        ,   co.Assigned_User_ID As Assigned_Collector 
        ,   u.Merchant_UserID As Emp_User_ID 
        ,   bc.Date_Created As Tran_Date_Time 
        ,   bc.Bc_No As Tran_Id 
        ,   la.Appl_No As Tran_Lynk_Id 
        ,   11 As Tran_Type_Id 
        ,   NULL As Tran_Mode 
        ,   Case When r.CSOType=1 Then 
                Case When ISNULL(bc.Finamt,0)> 0 AND ISNULL(bc.Finamt,0) >= ISNULL(r.FinCharge,0) 
                        Then ISNULL(r.Interest_Fee,0) 
                    When ISNULL(bc.Finamt,0)> 0 AND ISNULL(bc.Finamt,0) < ISNULL(r.FinCharge,0) 
                        Then Round((ISNULL(bc.Finamt,0)*ISNULL(r.Interest_Fee,0))/ISNULL(r.FinCharge,0),2) 
                    When ISNULL(bc.Finamt,0) < 0 AND ISNULL(bc.Finamt,0)>= ISNULL(r.FinCharge,0) 
                        Then ISNULL(r.Interest_Fee,0) *-1 
                    When ISNULL(bc.Finamt,0)< 0 AND ISNULL(r.FinCharge,0)<>0 AND ISNULL(bc.Finamt,0)< ISNULL(r.FinCharge,0) 
                        Then Round(((ISNULL(bc.Finamt,0)*ISNULL(r.Interest_Fee,0))/ISNULL(r.FinCharge,0)),2) 
                    ELSE 0 
                End 
                ELSE 
                    ISNULL (bc.Finamt,    0) 
            END As Total_Amount_Of_Transaction 
        ,   6 As Tran_Account 
        ,   NULL As Fee_Type 
        ,   la.Cashdisbmode As Loan_Disburse_Subtype 
        ,   NULL As Payment_Sub_Type 
        ,   NULL As Check_Number 
        ,   NULL As Returntype 
        ,   NULL As Return_Item_Count 
        ,   c.Cust_State 
        ,   NULL As ACH_No 
        ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 
    
    From    dbo.ca_Bankruptcy_charges bc WITH (NOLOCK) 
	Inner Join 
            dbo.ca_Loan_Appl la WITH (NOLOCK) On bc.Appl_No = la.Appl_No 
	Inner Join 
            dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
	Inner Join 
            dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
	Inner Join 
            dbo.ca_RateMaster r WITH (NOLOCK) ON la.RateID=r.RateID AND CSOType=1 
	Left Join 
            dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
	Left Join 
            dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
    Where   
			bc.Date_Created >= @minDate And 
            bc.Date_Created < @maxDate And 
            bc.Bc_Flag = 'C' And 
            la.Merch_Store_ID like @MerchantNo + '%' And 
            ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
            la.User_Id = u.User_Id;
 END 
 
-- ****************************************************************************/ 
--Bankruptcy charges Fourth 
--Fee charges 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        c.Cust_MerchantID As Merchant_Id 
    ,   la.Merch_Store_Id As Loan_Originating_Store_Id 
    ,   la.Merch_Store_Id As Transaction_Originating_Store_Id 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   c.Cust_Fname + ' ' +ISNULL(c.Cust_MName,'')+' '+ c.Cust_Lname As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   co.PlacedIntoCollections As O_Collection_Date 
    ,   co.Assigned_User_ID As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   bc.Date_Created As Tran_Date_Time 
    ,   bc.Bc_No As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   11 As Tran_Type_Id 
    ,   NULL As Tran_Mode 
    ,   ISNULL(bc.Feeamt,    0) As Total_Amount_Of_Transaction 
    ,   3 As Tran_Account 
    ,   NULL As Fee_Type 
    ,   la.Cashdisbmode As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   NULL As ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID
 
From    dbo.ca_Bankruptcy_charges bc WITH (NOLOCK) 
Inner Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On bc.Appl_No = la.Appl_No 
Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Inner Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id 
Left Join 
        dbo.ca_Collections co WITH (NOLOCK) On la.Appl_No = co.Appl_No 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		bc.Date_Created >= @minDate And 
        bc.Date_Created < @maxDate And 
        bc.Bc_Flag = 'C' And 
        la.Merch_Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,la.Merch_Store_Id) = la.Merch_Store_Id And 
        la.User_Id = u.User_Id;
--**************************************CHARGE OFF SECTION END ****************************************

-- ****************************************************************************/ 
--Processed Ach Fifth 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        Left ( ap.Store_No, 5 ) As Merchant_Id 
    ,   'loan_Originating_Store_Id' = 
            Case ap.Ach_For 
                When 'n' Then ap.Store_No 
                Else la.Merch_Store_Id 
            End 
    ,   'transaction_Originating_Store_Id' = 
            Case ap.Ach_For 
                When 'n' Then ap.Store_No 
                Else la.Merch_Store_Id 
            End 
    ,   la.Appl_No As Loan_Id 
    ,   la.Cust_Ssn 
    ,   ap.Name As Cust_Name 
    ,   ISNULL(la.Origin_Date,la.Date_Created) As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   NULL As O_Collection_Date 
    ,   NULL As Assigned_Collector 
    ,   u.Merchant_UserID As Emp_User_ID 
    ,   ap.ACH_Sent_Time As Tran_Date_Time 
    ,   ap.Ach_No As Tran_Id 
    ,   la.Appl_No As Tran_Lynk_Id 
    ,   'tran_Type_Id' = 10 
    ,   Tran_Mode = Case ap.Ach_For 
                        When 'b' Then 'A' 
                        When 'C' Then 'A' 
                        When 'm' Then 'A' 
                        When 'n' Then 'b' 
                    End 
    ,   ap.Ach_Amt As Total_Amount_Of_Transaction 
    ,   NULL As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   ap.ACH_No 
    ,   ISNULL(ou.Merchant_Userid,'') As Emp_Origin_UserID 

From    dbo.ca_Ach_Processed ap WITH (NOLOCK) 
Left Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) On la.Appl_No = ap.Appl_No 
Left Join 
        dbo.ca_Customer c WITH (NOLOCK) On la.Cust_Id = c.Cust_Id 
Left Join 
        dbo.ca_User u WITH (NOLOCK) On c.Cust_MerchantID = u.Merch_Id  And la.User_Id = u.User_Id 
Left Join 
        dbo.ca_User ou WITH (NOLOCK) On c.Cust_MerchantID = ou.Merch_Id AND ou.User_ID=la.origin_user 
Where   
		ap.Ach_Sent_Time >= @minDate And 
        ap.Ach_Sent_Time < @maxDate And 
        ap.Store_No like @MerchantNo + '%' And 
        ISNULL(@StoreNo,ap.Store_No) = ap.Store_No And 
        ap.IsDeleted=0;
        
-- ****************************************************************************/ 
--Petty Cash Sixth 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        Left ( pct.Store_Id, 5 ) As Merchant_Id 
    ,   'loan_Originating_Store_Id' = pct.Store_Id 
    ,   'transaction_Originating_Store_Id' = pct.Store_Id 
    ,   NULL As Loan_Id 
    ,   NULL As Cust_Ssn 
    ,   NULL As Cust_Name 
    ,   NULL As Loan_Orig_Date 
    ,   NULL As Loan_Due_Date 
    ,   NULL As Loan_Type 
    ,   NULL As Loan_Status 
    ,   NULL As O_Collection_Date 
    ,   NULL As Assigned_Collector 
    ,   UserCreated As Emp_User_ID 
    ,   Tran_Date As Tran_Date_Time 
    ,   pct.Pettycashtranid As Tran_Id 
    ,   NULL As Tran_Lynk_Id 
    ,   'tran_Type_Id' = 12 
    ,   'C' As Tran_Mode 
    ,   pct.Tran_Amount As Total_Amount_Of_Transaction 
    ,   NULL As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   NULL As Cust_State 
    ,   NULL As ACH_No 
    ,   NULL AS Emp_Origin_UserID
     
From    dbo.ca_PettyCashTransaction pct WITH (NOLOCK) 

Where   pct.Store_ID like @MerchantNo + '%' And 
        ISNULL(@StoreNo,pct.Store_Id) = pct.Store_Id And 
        pct.Tran_Date >= @minDate And 
        pct.Tran_Date < @maxDate;
        
-- ****************************************************************************/ 
--Branch Bank Deposit Seventh 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        Left ( Merch_Store_ID, 5) AS Merchant_ID 
    ,   'Loan_Originating_Store_ID' = Merch_Store_ID 
    ,   'Transaction_Originating_Store_ID' = Merch_Store_ID 
    ,   NULL As Loan_ID 
    ,   NULL As Cust_SSN 
    ,   NULL As Cust_Name 
    ,   NULL As Loan_Orig_Date 
    ,   NULL As Loan_Due_Date 
    ,   NULL As Loan_Type 
    ,   NULL As Loan_Status 
    ,   NULL As O_Collection_Date 
    ,   NULL As Assigned_Collector 
    ,   User_ID As Emp_User_ID 
    ,   Eff_Bal_Date As Tran_Date_Time 
    ,   Balance_ID As Tran_ID 
    ,   NULL As Tran_Lynk_ID 
    ,   'Tran_Type_ID' = 13 
    ,   Tran_Mode = 'C' 
    ,   Actual_Deposit As Total_Amount_Of_Transaction 
    ,   NULL As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   NULL As Cust_State 
    ,   NULL As ACH_No 
    ,   NULL AS Emp_Origin_UserID 

From    dbo.ca_Balance b WITH (NOLOCK) 

Where   b.Eff_Bal_Date >= @MinDate AND 
        b.Eff_Bal_Date < @maxDate AND 
        b.Merch_Store_ID like @MerchantNo + '%' AND 
        b.Merch_Store_ID = ISNULL(@StoreNo, Merch_Store_ID) AND 
        b.Actual_Deposit > 0;
        
-- ****************************************************************************/ 
--Deposit Cash Over/Short Eight 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        Left ( Merch_Store_ID, 5) AS Merchant_ID 
    ,   'Loan_Originating_Store_ID' = Merch_Store_ID 
    ,   'Transaction_Originating_Store_ID' = Merch_Store_ID 
    ,   NULL As Loan_ID 
    ,   NULL As Cust_SSN 
    ,   NULL As Cust_Name 
    ,   NULL As Loan_Orig_Date 
    ,   NULL As Loan_Due_Date 
    ,   NULL As Loan_Type 
    ,   NULL As Loan_Status 
    ,   NULL As O_Collection_Date 
    ,   NULL As Assigned_Collector 
    ,   User_ID As Emp_User_ID 
    ,   Eff_Bal_Date As Tran_Date_Time 
    ,   Balance_ID As Tran_ID 
    ,   NULL As Tran_Lynk_ID 
    ,   'Tran_Type_ID' = CASE WHEN (TotOverShort > 0) THEN 14 Else 15 END 
    ,   Tran_Mode = 'C' 
    ,   ABS(TotOverShort) As Total_Amount_Of_Transaction 
    ,   NULL As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   NULL As Cust_State 
    ,   NULL As ACH_No 
    ,   NULL AS Emp_Origin_UserID 
    
From    dbo.ca_Balance b WITH (NOLOCK) 

Where   b.Eff_Bal_Date >= @MinDate AND 
        b.Eff_Bal_Date < @maxDate AND 
        b.Merch_Store_ID like @MerchantNo + '%' and 
        b.Merch_Store_ID = ISNULL(@StoreNo, Merch_Store_ID) AND 
        ABS(TotOverShort) > 0;
        
-- ****************************************************************************/ 
-- Cashed Checks 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        Left ( ck.StoreID, 5) AS Merchant_ID 
    ,   'Loan_Originating_Store_ID' = ck.StoreID 
    ,   'Transaction_Originating_Store_ID' = ck.StoreID 
    ,   la.Appl_No As Loan_ID 
    ,   c.Cust_SSN As Cust_SSN 
    ,   c.Cust_FName + ',    ' + c.Cust_MName + ' ' + ISNULL(c.Cust_LName,    '') As Cust_Name 
    ,   la.Date_Created As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   NULL As O_Collection_Date 
    ,   NULL As Assigned_Collector 
    ,   UserCreated As Emp_User_ID 
    ,   DateCreated As Tran_Date_Time 
    ,   CheckTypeID As Tran_ID 
    ,   NULL As Tran_Lynk_ID 
    ,   'Tran_Type_ID' = '17' 
    ,   Tran_Mode = 'K' 
    ,   CheckAmount As Total_Amount_Of_Transaction 
    ,   NULL As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   NULL As ACH_No 
    ,   NULL AS Emp_Origin_UserID 
    
From    dbo.ca_Checks ck WITH (NOLOCK) Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) ON ck.CustID = c.Cust_ID Left Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK)ON Cast ( ck.CheckRefNo as numeric(18) ) = la.Appl_No 

Where   ck.DateCreated >= @MinDate AND 
        ck.DateCreated < @MaxDate and 
        ck.StoreID Like @MerchantNo + '%' AND 
        ck.StoreID = ISNULL(@StoreNo, ck.StoreID) AND 
        ck.CheckNo = la.PrintedCheckNo AND 
        ck.CheckAmount = la.Req_Loan_Amt;
        
-- ****************************************************************************/ 
--Cashed Checks Disbursements 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        Left ( ck.StoreID, 5) AS Merchant_ID 
    ,   'Loan_Originating_Store_ID' = ck.StoreID 
    ,   'Transaction_Originating_Store_ID' = ck.StoreID 
    ,   la.Appl_No As Loan_ID 
    ,   c.Cust_SSN As Cust_SSN 
    ,   c.Cust_FName + ',    ' + c.Cust_MName + ' ' + ISNULL(c.Cust_LName,    '') As Cust_Name 
    ,   la.Date_Created As Loan_Orig_Date 
    ,   la.Req_Due_Date As Loan_Due_Date 
    ,   la.Loan_Type 
    ,   la.Loan_Status 
    ,   NULL As O_Collection_Date 
    ,   NULL As Assigned_Collector 
    ,   UserCreated As Emp_User_ID 
    ,   DateCreated As Tran_Date_Time 
    ,   CheckTypeID As Tran_ID 
    ,   NULL As Tran_Lynk_ID 
    ,   'Tran_Type_ID' = '18' 
    ,   Tran_Mode = 'C' 
    ,   CheckAmount - FeeAmount As Total_Amount_Of_Transaction 
    ,   NULL As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   c.Cust_State 
    ,   NULL As ACH_No 
    ,   NULL AS Emp_Origin_UserID 
    
From    dbo.ca_Checks ck WITH (NOLOCK) Left Join 
        dbo.ca_Loan_Appl la WITH (NOLOCK) ON Cast ( ck.CheckRefNo as numeric(18) ) = la.Appl_No Inner Join 
        dbo.ca_Customer c WITH (NOLOCK) ON ck.CustID = c.Cust_ID 
        
Where   ck.DateCreated >= @MinDate AND 
        ck.DateCreated < @MaxDate AND 
        ck.StoreID like @MerchantNo + '%' AND 
        ISNULL(@StoreNo,ck.StoreID)=ck.StoreID AND 
        ck.CheckNo = la.PrintedCheckNo AND 
        ck.CheckAmount = la.Req_Loan_Amt;
        
-- ****************************************************************************/ 
--Cash In Out 
-- ****************************************************************************/ 
Insert Into @DailyAccountingReport 
Select 
        Left ( c.StoreID, 5) AS Merchant_ID 
    ,   NULL As Loan_Originating_Store_ID 
    ,   'Transaction_Originating_Store_ID' = c.StoreID 
    ,   NULL As Loan_ID 
    ,   NULL As Cust_SSN 
    ,   NULL As Cust_Name 
    ,   NULL As Loan_Orig_Date 
    ,   NULL As Loan_Due_Date 
    ,   NULL As Loan_Type 
    ,   NULL As Loan_Status 
    ,   NULL As O_Collection_Date 
    ,   NULL As Assigned_Collector 
    ,   UserCreated As Emp_User_ID 
    ,   DateCreated As Tran_Date_Time 
    ,   CashSourceID As Tran_ID 
    ,   NULL As Tran_Lynk_ID 
    ,   'Tran_Type_ID' = '19' 
    ,   Tran_Mode = 'C' 
    ,   Amount As Total_Amount_Of_Transaction 
    ,   NULL As Tran_Account 
    ,   NULL As Fee_Type 
    ,   NULL As Loan_Disburse_Subtype 
    ,   NULL As Payment_Sub_Type 
    ,   NULL As Check_Number 
    ,   NULL As Returntype 
    ,   NULL As Return_Item_Count 
    ,   NULL As Cust_State 
    ,   NULL As ACH_No 
    ,   NULL AS Emp_Origin_UserID 
    
From    dbo.ca_Cash c WITH (NOLOCK) 

Where   c.DateCreated >= @MinDate AND 
        c.DateCreated < @MaxDate AND 
        c.StoreID like @MerchantNo + '%' AND 
        c.StoreID = ISNULL(@StoreNo,    c.StoreID);
        
Select 
        ISNULL(dar.Merchant_Id,'') As Merchant_Id 
    ,   ISNULL(Loan_Originating_Store_Id,'') As Loan_Originating_Store_Id 
    ,   ISNULL(Transaction_Originating_Store_Id,'') As  Transaction_Originating_Store_Id 
    ,   ISNULL(Cast ( Loan_Id AS varchar),'') As Loan_Id 
    ,   ISNULL(Cust_SSN,'') As Cust_SSN 
    ,   ISNULL(Cust_Name,'') As Cust_Name 
    ,   Convert(varchar,ISNULL(Loan_Orig_Date,'1/1/1900'),101) As Loan_Orig_Date 
    ,   Convert(varchar,ISNULL(Loan_Due_Date,'1/1/1900'),101) As Loan_Due_Date 
    ,   ISNULL(Loan_Type,'') As Loan_Type 
    ,   ISNULL(Loan_Status,'I') As Loan_Status 
    ,   Convert(varchar,ISNULL(OC_CollectionDate,'1/1/1900'),101) + ' '+ Convert(varchar,ISNULL(OC_CollectionDate,'1/1/1900'),108) As OC_CollectionDate 
    ,   ISNULL(Assigned_Collector,'') As Assigned_Collector 
    ,   ISNULL(Emp_User_Id,'') As Emp_User_Id 
    ,   Convert(varchar,ISNULL(Tran_Date_Time,'1/1/1900'),101) + ' '+ Convert(varchar,ISNULL(Tran_Date_Time,'1/1/1900'),108) As Tran_Date_Time 
    ,   Convert(varchar,GetDate(),101) + ' '+ Convert(varchar,GetDate(),108) As Report_Date 
    ,   ISNULL(Cast(Tran_Id AS varchar),'') As Tran_Id 
    ,   ISNULL(Cast(Tran_Lynk_Id AS varchar),'') As Tran_Lynk_Id 
    ,   ISNULL(Cast(dar.Tran_Type_Id AS varchar),'') As Tran_Type_Id 
    ,   ISNULL(Tran_Mode,'') As Tran_Mode 
    ,   ISNULL(Cast(Total_Amount_Of_Transaction As varchar),'') As Total_Amount_Of_Transaction 
    ,   ISNULL(Cast(dar.Tran_Account AS varchar),'') As Tran_Account 
    ,   ISNULL(Fee_Type,'') As Fee_Type 
    ,   ISNULL(Cast(Loan_Disburse_Subtype AS varchar),'') As Loan_Disburse_Subtype 
    ,   ISNULL(Cast(Payment_Sub_Type AS varchar),'') As Payment_Sub_Type 
    ,   ISNULL(Check_Number,'') As Check_Number 
    ,   ISNULL(Cast(Returntype AS varchar),'') As Returntype 
    ,   ISNULL(Cast(Return_Item_Count AS varchar),'') As Return_Item_Count 
    ,   ISNULL(glc.GL_Code_Debit1,'') As GL_Code_Debit1 
    ,   ISNULL(glc.GL_Code_Debit2 ,'') As GL_Code_Debit2 
    ,   ISNULL(glc.GL_Code_Credit1,'') As GL_Code_Credit1 
    ,   ISNULL(glc.GL_Code_Credit2,'') As GL_Code_Credit2 
    ,   ISNULL(dar.Cust_State,'') As Cust_State 
    ,   ISNULL(Cast(dar.ACH_No As Varchar),'') As ACH_No 
    ,   ISNULL(Emp_Origin_UserID,'') As Emp_Origin_UserID 
    
From    @DailyAccountingReport dar Left Join 
        dbo.ca_Merchant_GLCodes glc WITH (NOLOCK) ON dar.Merchant_ID = glc.Merchant_ID 
            AND dar.Tran_Type_Id = glc.Tran_Type_Id 
            AND dar.Tran_Account = glc.Tran_Account
             
Order By Loan_Id;


GO