const { Decimal } = require("decimal.js");
const { BigNumber, utils } = require("ethers");

const [_currentRatePerSec, _deltaTime, _utilization] = process.argv.slice(2);

// Utilization Rate Settings
const MIN_UTIL = new Decimal(75000).div(new Decimal(10).pow(5)); // 75%
const MAX_UTIL = new Decimal(85000).div(new Decimal(10).pow(5)); // 85%
const UTIL_PREC = new Decimal(1e5).div(new Decimal(10).pow(5)); // 5 decimals

// Interest Rate Settings (all rates are per second), 365.24 days per year
const MIN_INT = new Decimal(79123523).div(new Decimal(10).pow(18)); // 0.25% annual rate
const MAX_INT = new Decimal(146248508681).div(new Decimal(10).pow(18)); // 10,000% annual rate
const INT_HALF_LIFE = 43200; // given in seconds, equal to 4 hours

const getNewRate = (_currentRatePerSec, _deltaTime, _utilization) => {
  // 1e18 precision downgrade
  const currentRatePerSec = new Decimal(_currentRatePerSec).div(new Decimal(10).pow(18));
  const deltaTime = new Decimal(_deltaTime);
  // 1e5 precision downgrade
  const utilization = new Decimal(_utilization).div(new Decimal(10).pow(5));

  let newRatePerSec;

  if (utilization.lt(MIN_UTIL)) {
    const deltaUtilization = new Decimal(MIN_UTIL).sub(utilization).div(MIN_UTIL);
    const decayGrowth = new Decimal(INT_HALF_LIFE).add(deltaUtilization.mul(deltaUtilization).mul(deltaTime));
    newRatePerSec = currentRatePerSec.mul(INT_HALF_LIFE).div(decayGrowth);
    if (newRatePerSec.lt(MIN_INT)) {
      newRatePerSec = new Decimal(MIN_INT);
    }
  } else if (utilization.gt(MAX_UTIL)) {
    const deltaUtilization = utilization.sub(MAX_UTIL).div(new Decimal(1).sub(MAX_UTIL));
    const decayGrowth = new Decimal(INT_HALF_LIFE).add(deltaUtilization.mul(deltaUtilization).mul(deltaTime));
    newRatePerSec = currentRatePerSec.mul(decayGrowth).div(new Decimal(INT_HALF_LIFE));
    if (newRatePerSec.gt(MAX_INT)) {
      newRatePerSec = new Decimal(MAX_INT);
    }
  } else {
    newRatePerSec = currentRatePerSec;
  }

  console.log(
    utils.defaultAbiCoder.encode(["uint256"], [newRatePerSec.mul(new Decimal(10).pow(18)).round().toString()]),
  );
};
getNewRate(_currentRatePerSec, _deltaTime, _utilization);
