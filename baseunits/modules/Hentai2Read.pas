unit Hentai2Read;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, WebsiteModules, uData, uBaseUnit, uDownloadsManager,
  XQueryEngineHTML, synautil;

const
  dirurl = '/hentai-list/all/any/last-added/';
  cdnurl = 'http://hentaicdn.com';

implementation

function GetDirectoryPageNumber(const MangaInfo: TMangaInformation;
  var Page: Integer; const Module: TModuleContainer): Integer;
begin
  Result := NET_PROBLEM;
  Page := 1;
  if MangaInfo = nil then
    Exit(UNKNOWN_ERROR);
  if MangaInfo.FHTTP.GET(Module.RootURL + dirurl) then
  begin
    Result := NO_ERROR;
    with TXQueryEngineHTML.Create(MangaInfo.FHTTP.Document) do
      try
        Page := StrToIntDef(XPathString(
          '//ul[starts-with(@class,"pagination")]/li[last()-1]/a'), 1);
      finally
        Free;
      end;
  end;
end;

function GetNameAndLink(const MangaInfo: TMangaInformation; const ANames, ALinks: TStringList;
  const AURL: String; const Module: TModuleContainer): Integer;
var
  v: IXQValue;
  s: String;
begin
  Result := NET_PROBLEM;
  if MangaInfo = nil then
    Exit(UNKNOWN_ERROR);
  s := Module.RootURL + dirurl;
  if AURL <> '0' then
    s := s + IncStr(AURL) + '/';
  if MangaInfo.FHTTP.GET(s) then
  begin
    Result := NO_ERROR;
    with TXQueryEngineHTML.Create(MangaInfo.FHTTP.Document) do
      try
        for v in XPath('//a[@class="mangaPopover"]') do
        begin
          ALinks.Add(v.toNode.getAttribute('href'));
          ANames.Add(v.toString);
        end;
      finally
        Free;
      end;
  end;
end;

function GetInfo(const MangaInfo: TMangaInformation; const AURL: String;
  const Module: TModuleContainer): Integer;
var
  v: IXQValue;
  s: String;
begin
  Result := NET_PROBLEM;
  if MangaInfo = nil then
    Exit(UNKNOWN_ERROR);
  with MangaInfo.FHTTP, MangaInfo.mangaInfo do
  begin
    url := FillHost(Module.RootURL, AURL);
    if GET(url) then
    begin
      Result := NO_ERROR;
      with TXQueryEngineHTML.Create(Document) do
        try
          coverLink := XPathString('//img[@class="img-responsive border-black-op"]/@src');
          if coverLink <> '' then
            coverLink := TrimLeftChar(coverLink, ['/']);
          if coverlink <> '' then
            coverLink := MaybeFillHost(cdnurl, coverLink);
          if title = '' then
            title := XPathString('//h3/a/text()');
          authors := XPathStringAll(
            '//ul[@class="list list-simple-mini"]/li[starts-with(.,"Author")]/*[position()>1]',
            ['-']);
          artists := XPathStringAll(
            '//ul[@class="list list-simple-mini"]/li[starts-with(.,"Artist")]/*[position()>1]',
            ['-']);
          genres := XPathStringAll(
            '//ul[@class="list list-simple-mini"]/li[starts-with(.,"Parody") or starts-with(.,"Category") or starts-with(.,"Content") or starts-with(.,"Language")]/*[position()>1]', ['-']);
          s := XPathString('//ul[@class="list list-simple-mini"]/li[starts-with(.,"Status")]');
          if s <> '' then
          begin
            s := LowerCase(s);
            if Pos('ongoing', s) > 0 then
              status := '1'
            else if Pos('completed', s) > 0 then
              status := '0';
          end;
          summary := XPathStringAll(
            '//ul[@class="list list-simple-mini"]/li[starts-with(.,"Storyline")]/*[position()>1]');
          for v in XPath('//ul[starts-with(@class,"nav-chapters")]/li/a') do
          begin
            chapterLinks.Add(v.toNode.getAttribute('href'));
            chapterName.Add(XPathString('text()', v.toNode));
          end;
          InvertStrings([chapterLinks, chapterName]);
        finally
          Free;
        end;
    end;
  end;
end;

function GetPageNumber(const DownloadThread: TDownloadThread; const AURL: String;
  const Module: TModuleContainer): Boolean;
var
  v: IXQValue;
  Source: TStringList;
  i: Integer;
  s: String;
begin
  Result := False;
  if DownloadThread = nil then
    Exit;
  with DownloadThread.FHTTP, DownloadThread.manager.container do
  begin
    PageLinks.Clear;
    PageContainerLinks.Clear;
    PageNumber := 0;
    if GET(FillHost(Module.RootURL, AURL)) then
    begin
      Result := True;
      Source := TStringList.Create;
      try
        Source.LoadFromStream(Document);
        if Source.Count > 0 then
          for i := 0 to Source.Count - 1 do
            if Pos('var rff_imageList', Source[i]) > 0 then
            begin
              s := SeparateRight(Source[i], '=');
              if s <> '' then
              begin
                s := Trim(TrimRightChar(s, [';']));
                with TXQueryEngineHTML.Create(s) do
                  try
                    for v in XPath('json(*)()') do
                      PageLinks.Add(cdnurl + '/hentai' + v.toString);
                  finally
                    Free;
                  end;
              end;
              Break;
            end;
      finally
        Source.Free;
      end;
      if PageLinks.Count = 0 then
        with TXQueryEngineHTML.Create(Document) do
          try
            PageNumber := XPath(
              '(//ul[@class="dropdown-menu text-center list-inline"])[1]/li').Count;
          finally
            Free;
          end;
    end;
  end;
end;

function GetImageURL(const DownloadThread: TDownloadThread; const AURL: String;
  const Module: TModuleContainer): Boolean;
var
  s: String;
begin
  Result := False;
  if DownloadThread = nil then
    Exit;
  with DownloadThread.manager.container, DownloadThread.FHTTP do
  begin
    s := FillHost(Module.RootURL, AURL);
    if DownloadThread.workCounter > 0 then
      s := AppendURLDelim(s) + IncStr(DownloadThread.workCounter) + '/';
    if GET(s) then
    begin
      Result := True;
      with TXQueryEngineHTML.Create(Document) do
        try
          s := XPathString('//img[@id="arf-reader"]/@src');
          if s<>'' then
          begin
            s:=TrimLeftChar(s,['/']);
            PageLinks[DownloadThread.workCounter] := MaybeFillHost(cdnurl, s);
          end;
        finally
          Free;
        end;
    end;
  end;
end;

procedure RegisterModule;
begin
  with AddModule do
  begin
    Website := 'Hentai2Read';
    RootURL := 'http://hentai2read.com';
    SortedList := True;
    OnGetDirectoryPageNumber := @GetDirectoryPageNumber;
    OnGetNameAndLink := @GetNameAndLink;
    OnGetInfo := @GetInfo;
    OnGetPageNumber := @GetPageNumber;
    OnGetImageURL := @GetImageURL;
  end;
end;

initialization
  RegisterModule;

end.