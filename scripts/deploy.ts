import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
    const [deployer] = await ethers.getSigners();

    // Auction 계약 배포
    const AttendanceReward = await ethers.getContractFactory("AttendanceReward");
    const attendanceReward = await AttendanceReward.deploy(
        process.env.ATTENDANCETOKEN_ADD!,
        process.env.MINIMALFORWARDER_ADD!
    );
    await attendanceReward.waitForDeployment();
    console.log("AttendanceReward deployed to:", attendanceReward.target);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
