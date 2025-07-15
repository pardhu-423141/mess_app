import 'package:googleapis_auth/auth_io.dart';
class get_server_key{
  Future<String> server_token()async{
    final scopes=[
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging',
    ];
    final client =await clientViaServiceAccount(ServiceAccountCredentials.fromJson({
  "type": "service_account",
  "project_id": "collegemessapp",
  "private_key_id": "21a6105138f87deb15d9012813597c0eb08c0328",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDN3gcSKQFWHesI\n16xDbuw4RbkQ7VyfV6QEOdugMqYH/mHMsKMb03T1WZ0tw7G0Yll5wE0E0ofzSakM\nOmzqKqgyF5EqHcTZ1lzsrEpP6vnWbRQByg4L14NiDmqGZgd5vlTXS3QCtlcdfSeV\n15l62plenZqUh6xOYqmo1MdL1Xk31n9AqQ4GZhWBJQHIVmK1NY4HOE83OxDred93\nLzTrq5HJWGaOxp24xsmeokwDWXPwp60BOVIDT6FPhc4EteJDjQkfhd6Kh4Br3gff\nZg2IqiY+sfcdeYXHNB2B5x0djmf0PEU/10dh+XoIbP1HRKae4DIgo8XufNLK2mcd\nEtSx5Vw1AgMBAAECggEAALbyGFaLGiTtcXDqOKu0ZzeavlvMlAMGXztiL0qtt95i\nsYa1cj3ILKfce1GwFru2qs0Hl2oxrZ8GVrQHN8LhJZdeWiKTUdxEI1Avy9o5dsyX\nIrB0Xwcm/hqltQS6puoJuluZMf83CzOphQQkFMCYgrMSW8yixPzjsOHYNUOu8Yor\n+b/8fprnvOBL2L2SVFhoHDAEuB6ceXsJtAIttuZDHX7D6/S6M+N/YcBJTeiHqV6m\nE2bEd0elYUON19wAOsOU43LDKoPHdwdjQFGIrFoRZDx0GDzEeWPw6H11JVzPkAYV\nPsP4ccs2hm5MIIzJwkKq0E+m9T0Krgnp7nAgyZJ7oQKBgQD+UfWdD19hZzQMAOTW\ncYyPhJzgY6Wp/35adUOX+M/TioXw9syw5Yk9SHA2PovRmjuF65UmngEDYpTbyMiW\nGD7egfrauVSBimoXIwZfnbzKUMUPhWWbqhASBcOTgrPjPAmUSI+lULbbuh5f1h56\nAjXF7P0CkEdPBjn0n7PVAojSxQKBgQDPOiMhh7yct3D9nVZ2ajdkPdIdFrpuIftQ\nET6h7LIXakeU2jMitTH9taedJTNkj3ZXajaavqP1PFjp5FS5BdI29bUVgn3ZZmav\nPOWYqoPfPo6Sa8jYfpKMaAjwxRmeOXDXZVBmIWZEr0fMUAyCFAcspee57R6J3dcO\ngc4luA86sQKBgQCR28nFOXLXt0wHcl/MibU2/rTGkQALfsgl80lAGOiBB9qH99Qv\nxIWwiyIoSjkAjreCuDmDu20TVu/PGdnJE8DC9sM7vL01yn/MIz9diWcklaxfmX9M\nBv5Oh9XCfVzUf7Nywyb3hlJJtPYEuxYhnbDfgmsdlEgBj62fmhSWn2x/jQKBgQCE\nSbvVkt5QOTbTYFaq32GfB2wTj8fRuLXDRk7ydbS3B+zMVIMiXAOe0BFBW1c0kfTd\nFvvmy17FlhG4tj9zogixdydzpMsMNrfElJ6JWAk5QakoRdCAjESnh151vY1+GXM0\nvgOWPyoXHMI75rola/2sffixE3NUVZ8NLsZYA+kM8QKBgQDtvpHgHmBAmh52dqK6\nArgx48LAJg3uNMHokxZ6l4ACgZUZiHJbJ8i7d1JQsmkIrxzz6scQkYAJVoPHPI6F\nLOiIVq2+blb1eBq7rmtaU2zIu0ayWntziXegxTgikOySho4mplcK9UWBPEliMqa8\nBCK0Ky8TGVsEaKuHHseKPdSm4g==\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@collegemessapp.iam.gserviceaccount.com",
  "client_id": "115617127181454639106",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40collegemessapp.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
), scopes);
    final accessserverkey=client.credentials.accessToken.data;
    return accessserverkey;
  }
}