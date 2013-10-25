provider             = "twitter"
http                 = require "https"
koding               = require './bongo'
{OAuth}              = require "oauth"

{
  renderOauthPopup
  saveOauthToSession
}                    = require './helpers'

{
  key
  secret
  request_url
  access_url
  version
  redirect_uri
  signature
}                    = KONFIG[provider]

module.exports = (req, res)->
  {oauth_token, oauth_verifier} = req.query
  {clientId}                    = req.cookies
  {JSession}                    = koding.models

  JSession.one {clientId}, (err, session)->
    if err
      renderOauthPopup res, {error:err, provider}
      return

    {foreignAuth}        = session
    {username}           = session.data
    {requestTokenSecret} = foreignAuth[provider]

    client = new OAuth request_url, access_url, key, secret, version,
      redirect_uri, signature

    client.getOAuthAccessToken oauth_token, requestTokenSecret, oauth_verifier,
      (err, oauthAccessToken, oauthAccessTokenSecret, results)->
        if err
          renderOauthPopup res, {error:err, provider}
          return

        client.get 'https://api.twitter.com/1.1/account/verify_credentials.json',
          oauthAccessToken, oauthAccessTokenSecret, (error, data)->
            if err
              renderOauthPopup res, {error:err, provider}
              return

            try
              response = JSON.parse data
            catch e
              renderOauthPopup res, {error:"twitter err: parsing json", provider}
              return

            twitter                   = foreignAuth[provider]
            twitter.token             = oauthAccessToken
            twitter.accessTokenSecret = oauthAccessTokenSecret
            twitter.foreignId         = response.id
            twitter.profile           = response

            saveOauthToSession twitter, clientId, provider, (err)->
              if err
                renderOauthPopup res, {error:err, provider}
                return

              renderOauthPopup res, {error:null, provider}
