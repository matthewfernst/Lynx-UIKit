import { GraphQLError } from "graphql";

import { deleteItem, getItemByIndex, updateItem } from "../../aws/dynamodb";
import { checkHasUserId, checkIsValidUserAndHasValidInvite } from "../../auth";
import { deleteObjectsInBucket } from "../../aws/s3";
import { OAuthType, idKeyFromIdType, verifyToken } from "./createUserOrSignIn";
import { Context } from "../../index";
import { BAD_REQUEST, User } from "../../types";
import {
    USERS_TABLE,
    PROFILE_PICS_BUCKET,
    SLOPES_UNZIPPED_BUCKET
} from "../../../infrastructure/lynxStack";

interface Args {
    combineWith: {
        type: OAuthType;
        id: string;
        token?: string;
    };
}

const combineOAuthAccounts = async (
    _: any,
    args: Args,
    context: Context,
    info: any
): Promise<User> => {
    checkHasUserId(context);
    checkIsValidUserAndHasValidInvite(context);
    const { type, id, token } = args.combineWith;
    const idKey = idKeyFromIdType(type);
    const otherUser = (await getItemByIndex(USERS_TABLE, idKey, id)) as User;
    if (!otherUser) {
        if (!token) {
            throw new GraphQLError("User Does Not Exist and No Token Provided", {
                extensions: { code: BAD_REQUEST }
            });
        }
        await verifyToken(type, id, token);
        return await updateItem(USERS_TABLE, context.userId, idKey, id);
    }
    await deleteItem(USERS_TABLE, otherUser.id);
    await deleteObjectsInBucket(PROFILE_PICS_BUCKET, otherUser.id);
    await deleteObjectsInBucket(SLOPES_UNZIPPED_BUCKET, otherUser.id);
    return await updateItem(USERS_TABLE, context.userId, idKey, id);
};

export default combineOAuthAccounts;
