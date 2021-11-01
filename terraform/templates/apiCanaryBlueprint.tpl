var synthetics = require('Synthetics');
const log = require('SyntheticsLogger');
const syntheticsConfiguration = synthetics.getConfiguration();


const apiCanaryBlueprint = async function () {

    syntheticsConfiguration.setConfig({
        restrictedHeaders: [], // Value of these headers will be redacted from logs and reports
        restrictedUrlParameters: [] // Values of these url parameters will be redacted from logs and reports
    });
    
    // Handle validation for positive scenario
    const validateSuccessful = async function(res) {
        return new Promise((resolve, reject) => {
            if (res.statusCode < 200 || res.statusCode > 299) {
                throw res.statusCode + ' ' + res.statusMessage;
            }
     
            let responseBody = '';
            res.on('data', (d) => {
                responseBody += d;
            });
     
            res.on('end', () => {
                // Add validation on 'responseBody' here if required.
                resolve();
            });
        });
    };
    
    let requestOptionsStep1 = {
        hostname: '${load_balancer_endpoint}',
        method: 'GET',
        path: '',
        port: '80',
        protocol: 'http:',
        body: "",
        headers: {}
    };
    requestOptionsStep1['headers']['User-Agent'] = [synthetics.getCanaryUserAgentString(), requestOptionsStep1['headers']['User-Agent']].join(' ');

   let stepConfig1 = {
        includeRequestHeaders: false,
        includeResponseHeaders: false,
        includeRequestBody: false,
        includeResponseBody: false,
        continueOnHttpStepFailure: true
    };

    await synthetics.executeHttpStep('Verify ${load_balancer_endpoint}', requestOptionsStep1, validateSuccessful, stepConfig1);

    
};

exports.handler = async () => {
    return await apiCanaryBlueprint();
};

