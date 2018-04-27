'this VBscript instructs the user to choose an excel file that is in a standard excel template
'then the script creates csvs from each of the sheets of the excel template
'then the script runs the new and improved gwl_jobmaker.pl program and the calc volumes program 
'then the script points the user to their output.

Dim runstring
'runstring ="perl C:\cygwin64\home\mpanisc\DiNA_GWLscripting\dna_dist\April2018_distribution\lateAprilCoding\3_25apr2018\DiNA_jobmaker1_0.pl"
backend ="DiNA_jobmaker1_1.pl"
csv_format = 6

'1: VBscript instructs the user to choose an excel file that is in a standard excel template
'Set objFSO = CreateObject("Scripting.FileSystemObject")
'src_file = objFSO.GetAbsolutePathName(Wscript.Arguments.Item(0))
'dest_file = objFSO.GetAbsolutePathName(WScript.Arguments.Item(1))
'src_file = Wscript.Arguments.Item(0)
WScript.Echo "So you want a gwl jobfile for DNA rearraying right? Please choose the excel jobfile prepared using the standard template. It should have one page labeled 'Source' and one or more pages beginning with B1_, B2_, B3_... for each batch. If source positions are not provided, they will be chosen. If you would like to edit those positions, please do that in the output excel file and run the script again." 
Set wShell=CreateObject("WScript.Shell")
Set oExec=wShell.Exec("mshta.exe ""about:<input type=file id=FILE><script>FILE.click();new ActiveXObject('Scripting.FileSystemObject').GetStandardStream(1).WriteLine(FILE.value);close();resizeTo(0,0);</script>""")
sFileSelected = oExec.StdOut.ReadLine
'wscript.echo sFileSelected
src_file =sFileSelected

'this is where i parse the source file to get the folder, split on slashes
'Dim src_split()
'WScript.Echo src_file
src_split = Split(src_file,"\",-1)
'WScript.Echo src_split(1)
Redim Preserve src_split (Ubound(src_split)-1)
src_folder=Join(src_split, "\")
'WScript.Echo src_folder
runstring = "perl " &src_folder & "\"& backend & " " & src_folder & src_folder &"\Source.txt"
'open excel, open selected book
Dim oExcel
Set oExcel = CreateObject("Excel.Application")
Set oBook = oExcel.Workbooks.Open(src_file)

Dim oBook
Dim n
Dim pages(100) '<store locations of sheets to useas arguments for perl scriptbetter not be more than 100 pages
n=oBook.Worksheets.Count
'WScript.Echo n
for i=1 to n

    'WScript.Echo i
    iminus1=i-1
    oBook.Worksheets(i).Activate
    dest_i= src_folder & "\" & oBook.Activesheet.Name & ".txt"
    name_i=oBook.Activesheet.Name & ".txt"
    'vart=VarType(pages(iminus1))'vart=VarType(dest_i)
    'WScript.Echo vart 'it's a string as expected

    'check if starts with "B", and only keep if it does
    startswithB=InStr(1,name_i,"B",1)
    If startswithB = 1 Then
        pages(iminus1)=dest_i
        'dest_i= "C:\cygwin64\home\mpanisc\DiNA_GWLscripting\dna_dist\April2018_distribution\" & oBook.Activesheet.Name & ".txt"
        oBook.SaveAs dest_i, csv_format
        'WScript.Echo pages(iminus1)
        runstring= runstring & " " & dest_i'name_i
    End If

    'check if starts with "B", and only keep if it does
    If name_i = "Source.txt" Then
        pages(iminus1)=dest_i
        'dest_i= "C:\cygwin64\home\mpanisc\DiNA_GWLscripting\dna_dist\April2018_distribution\" & oBook.Activesheet.Name & ".txt"
        oBook.SaveAs dest_i, csv_format
        'WScript.Echo pages(iminus1)
        'runstring= runstring & " " & name_i
    End If


Next
oBook.Close False ' oBook.Close False
oExcel.Quit

'now we have our text files made, each path kept in pages(),and the n of howmany pages
'let's run the perl program with all these pages as inputs.

Set oShell = CreateObject ("WScript.Shell") 
WScript.Echo("**"&runstring&"**")
oShell.run (runstring & " Source.txt ")

WScript.Echo "Your jobfiles are in the same folder as the xls you chose."
Dim shell
Set shell = wscript.CreateObject("Shell.Application")
shell.Open(src_folder)