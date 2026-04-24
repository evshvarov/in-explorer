# useful commands
## clean up docker
use it when docker says "There is no space left on device". It will remove built but not used images and other temporary files.
```
docker system prune -f
```

## if the previous doesn't help anymore:
```
docker system prune -a
```

```
docker rm -f $(docker ps -qa)
```

## build container with no cache
```
docker compose build --no-cache --progress=plain
```
## start iris container
```
docker compose up -d
```

## open iris terminal in docker
```
docker compose exec iris iris session iris -U USER
```

## map iris key from Mac home directory to IRIS in container
- ~/iris.key:/usr/irissys/mgr/iris.key

## install git in the docker image
## add git in dockerfile
USER root
RUN apt update && apt-get -y install git

USER ${ISC_PACKAGE_MGRUSER}


## install docker-compose
```
sudo curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

```

## select zpm test registry
```
repo -n registry -r -url https://test.pm.community.intersystems.com/registry/ -user test -pass PassWord42
```

## switch back to a public zpm registry
```
repo -r -n registry -url https://pm.community.intersystems.com/ -user "" -pass ""
```

## export a global in runtime into the repo
```
d $System.OBJ.Export("GlobalD.GBL","/home/irisowner/dev/src/gbl/GlobalD.xml")
```

## create a web app in dockerfile
```
zn "%SYS" \
  write "Create web application ...",! \
  set webName = "/csp/irisweb" \
  set webProperties("NameSpace") = "IRISAPP" \
  set webProperties("Enabled") = 1 \
  set webProperties("CSPZENEnabled") = 1 \
  set webProperties("AutheEnabled") = 32 \
  set webProperties("iKnowEnabled") = 1 \
  set webProperties("DeepSeeEnabled") = 1 \
  set sc = ##class(Security.Applications).Create(webName, .webProperties) \
  write "Web application "_webName_" has been created!",!
```



```
do $SYSTEM.OBJ.ImportDir("/home/irisowner/dev/src",, "ck")
```


### run tests described in the module

IRISAPP>zpm
IRISAPP:zpm>load /home/irisowner/dev
IRISAPP:zpm>test package-name

### install ZPM with one line
    // Install ZPM
    set $namespace="%SYS", name="DefaultSSL" do:'##class(Security.SSLConfigs).Exists(name) ##class(Security.SSLConfigs).Create(name) set url="https://pm.community.intersystems.com/packages/zpm/latest/installer" Do ##class(%Net.URLParser).Parse(url,.comp) set ht = ##class(%Net.HttpRequest).%New(), ht.Server = comp("host"), ht.Port = 443, ht.Https=1, ht.SSLConfiguration=name, st=ht.Get(comp("path")) quit:'st $System.Status.GetErrorText(st) set xml=##class(%File).TempFilename("xml"), tFile = ##class(%Stream.FileBinary).%New(), tFile.Filename = xml do tFile.CopyFromAndSave(ht.HttpResponse.Data) do ht.%Close(), $system.OBJ.Load(xml,"ck") do ##class(%File).Delete(xml)


## add git
USER root

RUN apt update && apt-get -y install git

USER ${ISC_PACKAGE_MGRUSER}


## Python virtual environment
python -m vevn .venv



AND (:startDate = '' OR t.DateOfSale >= :startDate)
AND (:endDate = '' OR t.DateOfSale <= :endDate)
  

(:startDate = '' OR t.DateOfSale >= :startDate)
  AND (:endDate = '' OR t.DateOfSale <= :endDate)


WHERE TO_DATE(DateSubmitted, 'MM/DD/YYYY') BETWEEN TO_DATE('07/01/2016','MM/DD/YYYY') AND TO_DATE('07/31/2016','MM/DD/YYYY')




PasswordHash=f39e4300ca0eafc90fffffd6dee0740b370204787af445cd0f4ca729fa3f88375729d618e0d26f571d862d6f7769d6d5accfc77d29f559933f339168f9b7e3d8,0bfb9655eef35452881570a28efc96bbf56217ff3c9bf0da9d9a11b58d85a8486946e485470b10a9542480646b5e383552b0f27b7f69a6333753913039b2dc63,10000,SHA512



PasswordHash=bfa976ebf01d7abe1b2e22f09010ad8da78fe296f027ba2cc180970de08589cff56069741a4774f11868bb1906e3232bc92dcba9a308eca4b88168d53248af1f,c11b35fe5ce3e2270bdabfc3061b37daa5888f7131ce430a388a25d8eb13e6ad3f1258c0442455479da3a8125866a7348708f2917b705f543b22bba3de4d3c7a,10000,SHA512
